resource "aws_prometheus_workspace" "prom_workspace" {
  alias = "${var.prefix}-ecs-prometheus"
}

resource "aws_service_discovery_private_dns_namespace" "private_dns_namespace" {
  name        = "prom.${var.prefix}.${data.aws_route53_zone.r53_zone.name}"
  description = "service discovery private dns namespace"
  vpc         = data.aws_vpc.vpc.id
}

resource "aws_service_discovery_service" "discovery_service" {
  name = "ecs-discovery-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.private_dns_namespace.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "WEIGHTED"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    METRICS_PATH = "/metrics",
    METRICS_PORT = "3000"
  }
}

resource "aws_ecs_task_definition" "rearc_quest_prometheus_task" {
  family                   = "${var.prefix}-prometheus"
  container_definitions    = <<DEFINITION
  [
      {
         "name":"config-reloader",
         "image":"public.ecr.aws/awsvijisarathy/prometheus-sdconfig-reloader:1.0",
         "user":"root",
         "cpu": 128,
         "memory": 128,
         "environment":[
            {
               "name":"CONFIG_FILE_DIR",
               "value":"/etc/config"
            },
            {
               "name":"CONFIG_RELOAD_FREQUENCY",
               "value":"60"
            }
         ],
         "mountPoints":[
            {
               "sourceVolume":"configVolume",
               "containerPath":"/etc/config",
               "readOnly":false
            }
         ],
         "logConfiguration":{
            "logDriver":"awslogs",
            "options":{
               "awslogs-group":"/ecs/Prometheus",
               "awslogs-create-group":"true",
               "awslogs-region":"${var.aws_region}",
               "awslogs-stream-prefix":"reloader"
            }
         },
         "essential":true
      },
      {
         "name":"aws-iamproxy",
         "image":"public.ecr.aws/aws-observability/aws-sigv4-proxy:1.0",
         "cpu": 256,
         "memory": 256,
         "portMappings":[
            {
               "containerPort":8080,
               "protocol":"tcp"
            }
         ],
         "command":[
            "--name",
            "aps",
            "--region",
            "${var.aws_region}",
            "--host",
            "aps-workspaces.${var.aws_region}.amazonaws.com"
         ],
         "logConfiguration":{
            "logDriver":"awslogs",
            "options":{
               "awslogs-group":"/ecs/Prometheus",
               "awslogs-create-group":"true",
               "awslogs-region":"${var.aws_region}",
               "awslogs-stream-prefix":"iamproxy"
            }
         },
         "essential":true
      },
      {
         "name":"prometheus-server",
         "image":"quay.io/prometheus/prometheus:v2.24.0",
         "user":"root",
         "cpu": 512,
         "memory": 512,
         "portMappings":[
            {
               "containerPort":9090,
               "protocol":"tcp"
            }
         ],
         "command":[
            "--storage.tsdb.retention.time=15d",
            "--config.file=/etc/config/prometheus.yaml",
            "--storage.tsdb.path=/data",
            "--web.console.libraries=/etc/prometheus/console_libraries",
            "--web.console.templates=/etc/prometheus/consoles",
            "--web.enable-lifecycle"
         ],
         "logConfiguration":{
            "logDriver":"awslogs",
            "options":{
               "awslogs-group":"/ecs/Prometheus",
               "awslogs-create-group":"true",
               "awslogs-region":"${var.aws_region}",
               "awslogs-stream-prefix":"server"
            }
         },
         "mountPoints":[
            {
               "sourceVolume":"configVolume",
               "containerPath":"/etc/config",
               "readOnly":false
            },
            {
               "sourceVolume":"logsVolume",
               "containerPath":"/data"
            }
         ],
         "healthCheck":{
            "command":[
               "CMD-SHELL",
               "wget http://localhost:9090/-/healthy -O /dev/null|| exit 1"
            ],
            "interval":10,
            "timeout":2,
            "retries":2,
            "startPeriod":10
         },
         "dependsOn": [
            {
                "containerName": "config-reloader",
                "condition": "START"
            },
            {
               "containerName": "aws-iamproxy",
               "condition": "START"
           }
        ],
         "essential":true
      }
   ]
DEFINITION

  volume {
    name      = "configVolume"
    host_path = {}
  }

  volume {
    name      = "logsVolume"
    host_path = {}
  }

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 1024
  cpu                      = 1024
  execution_role_arn       = aws_iam_role.ecs_prometheus_role.arn
}

resource "aws_iam_role" "ecs_prometheus_role" {
  name_prefix        = var.prefix
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_prometheus_role_policy" {
  role       = aws_iam_role.ecs_prometheus_role.name
  policy_arn = aws_iam_policy.ecs_prometheus_policy.arn
}

resource "aws_iam_policy" "ecs_prometheus_policy" {
  name_prefix = var.prefix
  description = "Policy to allow Prometheus to send metrics to AMP."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "aps:RemoteWrite",
          "aps:GetSeries",
          "aps:GetLabels",
          "aps:GetMetricMetadata"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "servicediscovery:*"
        ]
        Resource = "*"
      }
    ]
  })
}
