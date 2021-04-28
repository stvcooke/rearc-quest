resource "aws_ecr_repository" "repo" {
  name                 = "rearc-quest-ecr"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  name = "rearc-quest-ecs"

  container_insights = true

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
    }
  ]

  tags = var.tags
}
