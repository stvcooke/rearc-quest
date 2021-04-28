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

resource "aws_ecs_task_definition" "rearc_quest_pre_secret_task" {
  family                   = "rearc-quest-pre-secret-exec"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "rearc-quest-pre-secret-exec",
      "image": "${aws_ecr_repository.repo.repository_url}:exec",
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
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  tags = var.tags
}

resource "aws_ecs_service" "rearc_quest_pre_secret_service" {
  name            = "rearc-quest-pre-secret-exec"
  cluster         = module.ecs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.rearc_quest_pre_secret_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = [ var.public_subnet_id, var.public_subnet2_id ]
    assign_public_ip = true
    security_groups  = [ aws_security_group.service_security_group.id ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
    container_name   = aws_ecs_task_definition.rearc_quest_pre_secret_task.family
    container_port   = 3000 # The container port
  }

  tags = var.tags
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole"
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

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_alb" "rearc_quest_ecs_lb" {
  name               = "rearc-1uest-ecs-lb"
  load_balancer_type = "application"
  subnets = [
    var.public_subnet_id,
    var.public_subnet2_id
  ]
  security_groups = [ aws_security_group.load_balancer_security_group.id ]
}

resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "service_security_group" {
  vpc_id = var.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"

    security_groups = [ aws_security_group.load_balancer_security_group.id ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "ecs_target_group" {
  name        = "rarc-quest-ecs-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
  health_check {
    matcher = "200,301,302"
    path = "/"
  }
}

resource "aws_lb_listener" "ecs_listener" {
  load_balancer_arn = aws_alb.rearc_quest_ecs_lb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_target_group.arn
  }
}
