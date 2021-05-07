#! /bin/bash

STACK_PREFIX="$1"
DOMAIN="$2"
REGION="us-east-2"

# These values are hard coded (ish) because I don't want to filter json outputs in a bash script.
# See $ECR_REPO for a less complicated json outputs filter
STATE_BUCKET="${STACK_PREFIX}-remote-state-tf-state"
STATE_DYNAMODB="${STACK_PREFIX}-remote-state-tf-state-locking"

echo create empty vpc stack
# create empty stacks to avoid weird rollback errors
/usr/bin/aws cloudformation create-stack \
  --stack-name "${STACK_PREFIX}-vpc" \
  --template-body file://cloudformation/empty-stack.yaml \
  --region $REGION

echo create empty ecr stack
/usr/bin/aws cloudformation create-stack \
  --stack-name "${STACK_PREFIX}-ecr" \
  --template-body file://cloudformation/empty-stack.yaml \
  --region $REGION

echo create empty remoet state stack
/usr/bin/aws cloudformation create-stack \
  --stack-name "${STACK_PREFIX}-remote-state" \
  --template-body file://cloudformation/empty-stack.yaml \
  --region $REGION

echo updating ecr stack
# wait for stack creation to complete before updating
/usr/bin/aws cloudformation wait stack-create-complete \
  --stack-name "${STACK_PREFIX}-ecr" \
  --region $REGION
/usr/bin/aws cloudformation update-stack \
  --stack-name "${STACK_PREFIX}-ecr" \
  --template-body file://cloudformation/ecr.yaml \
  --region $REGION \
  --parameters ParameterKey=repositoryName,ParameterValue=$STACK_PREFIX

echo updating vpc stack
/usr/bin/aws cloudformation wait stack-create-complete \
  --stack-name "${STACK_PREFIX}-vpc" \
  --region $REGION
/usr/bin/aws cloudformation update-stack \
  --stack-name "${STACK_PREFIX}-vpc" \
  --template-body file://cloudformation/vpc.yaml \
  --region $REGION

echo updating remote-state stack
/usr/bin/aws cloudformation wait stack-create-complete \
  --stack-name "${STACK_PREFIX}-remote-state" \
  --region $REGION
/usr/bin/aws cloudformation update-stack \
  --stack-name "${STACK_PREFIX}-remote-state" \
  --template-body file://cloudformation/remote-state.yaml \
  --region $REGION

echo ensure ecr finished updating
/usr/bin/aws cloudformation wait stack-update-complete \
  --stack-name "${STACK_PREFIX}-ecr" \
  --region $REGION
# Store the repository url from the output of ecr.yaml
echo grabbing ecr repo url
ECR_REPO=$( \
  /usr/bin/aws cloudformation describe-stacks \
  --stack-name "${STACK_PREFIX}-ecr" \
  --region $REGION 2> /dev/null | \
  python3 -c "import sys, json; stacks = json.load(sys.stdin)['Stacks']; print([stack for stack in stacks if stack['StackName'] == '${STACK_PREFIX}-ecr'][0]['Outputs'][0]['OutputValue'])"

)

echo building docker image
DOCKER_TAG="${ECR_REPO}:${STACK_PREFIX}"
docker build -t $DOCKER_TAG .

echo logging into ECR to authenticate
ECR_URL=$( echo $ECR_REPO | awk -F/ '{print $1}' ) ## removes the `/repository` from ECR_REPO
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL

echo pushing docker image to ECR
docker image push $DOCKER_TAG

echo copying ecs/main.tf then updating backend from cloudformation
cp ecs/main.tf ecs_main.tf.bk
# replace lines with remote state hardcode
sed -i "10s/.*/    bucket = \"${STATE_BUCKET}\"/" ecs/main.tf
sed -i "12s/.*/    dynamodb_table = \"${STATE_DYNAMODB}\"/" ecs/main.tf
sed -i "13s/.*/    region = \"${REGION}\"/" ecs/main.tf

echo top 20 lines of ecs/main.tf for troubleshooting purposes
head -n 20 ecs/main.tf

echo ensuring remote state and vpc stacks are updated
# ensure vpc and remote state are ready
/usr/bin/aws cloudformation wait stack-update-complete \
  --stack-name "${STACK_PREFIX}-remote-state" \
  --region $REGION
/usr/bin/aws cloudformation wait stack-update-complete \
  --stack-name "${STACK_PREFIX}-vpc" \
  --region $REGION

echo Initiating terraform
cd ecs
terraform init -reconfigure

terraform apply -auto-approve \
  -var "prefix=${STACK_PREFIX}" \
  -var "image_tag=${STACK_PREFIX}" \
  -var "domain=${DOMAIN}" \
  -var "aws_region=${REGION}"

cd ..
mv ecs_main.tf.bk ecs/main.tf

echo ECS Services may take up to 5 minutes to spin up. Suggest using alpine image to speed things up.
