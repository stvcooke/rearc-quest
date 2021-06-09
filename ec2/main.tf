terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "rearc-quest-infra-tf-state"
    key = "rearc-quest/prod/ec2"
    dynamodb_table = "rearc-quest-infra-tf-state-locking"
    region = "us-east-2"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags = var.tags
}

data "aws_iam_policy" "ssm_policy" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_elb_service_account" "main" {}

data "aws_cloudformation_stack" "vpc_stack" {
  name = "${var.prefix}-vpc"
}
