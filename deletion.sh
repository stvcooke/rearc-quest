#! /bin/bash
#! /bin/bash

STACK_PREFIX="$1"
DOMAIN="$2"
REGION="us-east-2"

# These values are hard coded (ish) because I don't want to filter json outputs in a bash script.
# See creation.sh for use
STATE_BUCKET="${STACK_PREFIX}-remote-state-tf-state"
STATE_DYNAMODB="${STACK_PREFIX}-remote-state-tf-state-locking"

echo setting up main.tf
cp ecs/main.tf ecs_main.tf.bk
# replace lines with remote state hardcode
sed -i "10s/.*/    bucket = \"${STATE_BUCKET}\"/" ecs/main.tf
sed -i "12s/.*/    dynamodb_table = \"${STATE_DYNAMODB}\"/" ecs/main.tf
sed -i "13s/.*/    region = \"${REGION}\"/" ecs/main.tf

cd ecs

ACCESS_LOGS_BUCKET=$( terraform output | grep access_logs_bucket | awk -F\" '{print $2}' | tr -d [[:space:]] )
ECR_REPO=$( terraform output | grep ecr_url | awk -F\" '{print $2}' | tr -d [[:space:]] )

echo deleting access logs bucket
# empty access logs bucket so can be deleted in terraform destroy
/usr/bin/aws s3 rm s3://$ACCESS_LOGS_BUCKET --recursive
python3 -c "import boto3; s3 = boto3.resource('s3'); bucket = s3.Bucket('${ACCESS_LOGS_BUCKET}'); bucket.object_versions.all().delete(); bucket.delete()"

terraform destroy \
  -var "prefix=${STACK_PREFIX}" \
  -var "image_tag=${STACK_PREFIX}" \
  -var "domain=${DOMAIN}" \
  -var "aws_region=${REGION}"

cd ..
mv ecs_main.tf.bk ecs/main.tf

echo deleting state bucket
# empty and delete state bucket and logging bucket stack can be deleted
/usr/bin/aws s3 rm s3://$STATE_BUCKET --recursive
python3 -c "import boto3; s3 = boto3.resource('s3'); bucket = s3.Bucket('${STATE_BUCKET}'); bucket.object_versions.all().delete(); bucket.delete()"

echo deleting state loggign bucket
/usr/bin/aws s3 rm "s3://${STATE_BUCKET}-logging" --recursive
python3 -c "import boto3; s3 = boto3.resource('s3'); bucket = s3.Bucket('${STATE_BUCKET}-logging'); bucket.object_versions.all().delete(); bucket.delete()"

echo deleting remote state stack
/usr/bin/aws cloudformation delete-stack \
--stack-name "${STACK_PREFIX}-remote-state" \
--region $REGION

echo force deleting repository: $ECR_REPO
/usr/bin/aws ecr delete-repository \
--repository-name $ECR_REPO \
--force \
--region $REGION

/usr/bin/aws cloudformation delete-stack \
--stack-name "${STACK_PREFIX}-ecr" \
--region $REGION

echo deleting vpc stack
/usr/bin/aws cloudformation delete-stack \
--stack-name "${STACK_PREFIX}-vpc" \
--region $REGION
