resource "aws_flow_log" "vpc_flow_log" {
  log_destination      = aws_s3_bucket.access_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = data.aws_vpc.vpc.id
}

resource "aws_guardduty_detector" "detector" {
  enable = true
}

resource "aws_shield_protection" "shield" {
  name         = var.prefix
  resource_arn = aws_alb.rearc_quest_ecs_lb.arn
}
