# output "alb_dns" {
#   value = aws_lb.rearc_quest_alb.dns_name
# }

output "ecr_url" {
  value = data.aws_ecr_repository.repo.repository_url
}

output "ecs_alb_dns" {
  value = aws_alb.rearc_quest_ecs_lb.dns_name
}

output "http_url" {
  value = "http://${aws_route53_record.record.fqdn}"
}

output "https_url" {
  value = "https://${aws_route53_record.record.fqdn}"
}
