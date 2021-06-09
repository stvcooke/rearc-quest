module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  name = "${var.prefix}-ecs"

  container_insights = true

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy = [
    {
      capacity_provider = "FARGATE_SPOT"
    }
  ]
}

resource "aws_ecs_task_definition" "rearc_quest_pre_secret_task" {
  family                   = "${var.prefix}-pre-secret"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.prefix}-pre-secret",
      "image": "${data.aws_ecr_repository.repo.repository_url}:${var.image_tag}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "rearc_quest_pre_secret_service" {
  name            = "${var.prefix}-pre-secret"
  cluster         = module.ecs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.rearc_quest_pre_secret_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  service_registries {
    registry_arn   = aws_service_discovery_service.discovery_service.arn
  }

  network_configuration {
    subnets          = [ data.aws_subnet.private_subnet.id ]
    assign_public_ip = false
    security_groups  = [ aws_security_group.service_security_group.id ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = aws_ecs_task_definition.rearc_quest_pre_secret_task.family
    container_port   = 3000 # The container port
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name_prefix        = var.prefix
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "rearc_quest_post_secret_task" {
  family                   = "${var.prefix}-post-secret"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "${var.prefix}-post-secret",
      "image": "${data.aws_ecr_repository.repo.repository_url}:${var.image_tag}",
      "essential": true,
      "environment": [
        {
          "name": "SECRET_WORD",
          "value": "TwelveFactor"
        }
      ],
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

resource "aws_ecs_service" "rearc_quest_post_secret_service" {
  name            = "${var.prefix}-post-secret"
  cluster         = module.ecs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.rearc_quest_post_secret_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  service_registries {
    registry_arn   = aws_service_discovery_service.discovery_service.arn
  }

  network_configuration {
    subnets          = [ data.aws_subnet.private_subnet.id ]
    assign_public_ip = false
    security_groups  = [ aws_security_group.service_security_group.id ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_tls_target_group.arn
    container_name   = aws_ecs_task_definition.rearc_quest_post_secret_task.family
    container_port   = 3000 # The container port
  }
}
