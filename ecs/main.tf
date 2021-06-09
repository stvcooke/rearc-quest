terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket = "quest-remote-state-tf-state"
    key = "rearc-quest/prod/quest"
    dynamodb_table = "quest-remote-state-tf-state-locking"
    region = "us-east-2"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags = var.tags
}

data "aws_elb_service_account" "main" {}

data "aws_route53_zone" "r53_zone" {
  name         = "${var.domain}."
  private_zone = false
}

data "aws_cloudformation_stack" "vpc_stack" {
  name = "${var.prefix}-vpc"
}

data "aws_vpc" "vpc" {
  id = data.aws_cloudformation_stack.vpc_stack.outputs["VpcId"]
}

data "aws_subnet" "private_subnet" {
  id = data.aws_cloudformation_stack.vpc_stack.outputs["PrivateSubnet1"]
}

data "aws_subnet" "public_subnet" {
  id = data.aws_cloudformation_stack.vpc_stack.outputs["PublicSubnet1"]
}

data "aws_subnet" "public_subnet2" {
  id = data.aws_cloudformation_stack.vpc_stack.outputs["PublicSubnet2"]
}

data "aws_ecr_repository" "repo" {
  name = var.prefix
}
