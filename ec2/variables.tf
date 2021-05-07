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
