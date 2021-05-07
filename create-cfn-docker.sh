#! /bin/bash

STACK_PREFIX="$1"
DOMAIN="$2"
REGION="us-east-2"

# These values are hard coded (ish) because I don't want to filter json outputs in a bash script.
# See $ECR_REPO for a less complicated json outputs filter
STATE_BUCKET="${STACK_PREFIX}-remote-state-tf-state"
STATE_DYNAMODB="${STACK_PREFIX}-remote-state-tf-state-locking"

# /usr/bin/aws cloudformation create-stack \
# --stack-name "${STACK_PREFIX}-vpc" \
# --template-body file://cloudformation/empty-stack.yaml \
# --region $REGION
#
# /usr/bin/aws cloudformation create-stack \
# --stack-name "${STACK_PREFIX}-ecr" \
# --template-body file://cloudformation/empty-stack.yaml \
# --region $REGION
#
# /usr/bin/aws cloudformation create-stack \
# --stack-name "${STACK_PREFIX}-remote-state" \
# --template-body file://cloudformation/empty-stack.yaml \
# --region $REGION

# /usr/bin/aws cloudformation wait stack-create-complete \
# --stack-name "${STACK_PREFIX}-ecr"
# /usr/bin/aws cloudformation update-stack \
# --stack-name "${STACK_PREFIX}-ecr" \
# --template-body file://cloudformation/ecr.yaml \
# --region $REGION \
# --parameters ParameterKey=repositoryName,ParameterValue=$STACK_PREFIX

# /usr/bin/aws cloudformation wait stack-create-complete \
# --stack-name "${STACK_PREFIX}-vpc"
# /usr/bin/aws cloudformation update-stack \
# --stack-name "${STACK_PREFIX}-vpc" \
# --template-body file://cloudformation/vpc.yaml \
# --region $REGION
#
# /usr/bin/aws cloudformation wait stack-create-complete \
# --stack-name "${STACK_PREFIX}-remote-state"
# /usr/bin/aws cloudformation update-stack \
# --stack-name "${STACK_PREFIX}-remote-state" \
# --template-body file://cloudformation/remote-state.yaml \
# --region $REGION

# /usr/bin/aws cloudformation wait stack-update-complete \
# --stack-name "${STACK_PREFIX}-ecr" \
# --region $REGION
# # Store the repository url from the output of ecr.yaml
# ECR_REPO=$( \
#   /usr/bin/aws cloudformation describe-stacks \
#   --stack-name "${STACK_PREFIX}-ecr" \
#   --region $REGION 2> /dev/null | \
#   python3 -c "import sys, json; stacks = json.load(sys.stdin)['Stacks']; print([stack for stack in stacks if stack['StackName'] == '${STACK_PREFIX}-ecr'][0]['Outputs'][0]['OutputValue'])"
#
# )
#
# DOCKER_TAG="${ECR_REPO}:${STACK_PREFIX}"
# docker build -t $DOCKER_TAG .
#
# ECR_URL=$( echo $ECR_REPO | awk -F/ '{print $1}' ) ## removes the `/repository` from ECR_REPO
# aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL
#
# docker image push $DOCKER_TAG

cp ecs/main.tf ecs_main.tf.bk
# replace lines with remote state hardcode
sed -i "10s/.*/    bucket = \"${STATE_BUCKET}\"/" ecs/main.tf
sed -i "12s/.*/    dynamodb_table = \"${STATE_DYNAMODB}\"/" ecs/main.tf

cd ecs
# terraform init

terraform apply -auto-approve \
  -var "prefix=${STACK_PREFIX}" \
  -var "image_tag=${STACK_PREFIX}" \
  -var "domain=${DOMAIN}"

cd ..
mv ecs_main.tf.bk ecs/main.tf

echo ECS Services may take up to 5 minutes to spin up. Suggest using alpine image to speed things up.
