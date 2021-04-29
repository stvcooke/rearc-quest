variable "aws_region" {
  default = "us-east-2"
}

variable "prefix" {
  type = string

  default = "stvcooke-quest"
}

variable "tags" {
  type = map

  default = {
    cost-center = "stvcooke-quest"
    owner = "stvcooke"
  }
}

variable "private_subnet_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "public_subnet2_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "image_tag" {
  type    = string
  default = "latest"
}
