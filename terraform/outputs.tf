output "alb_dns" {
  value = aws_lb.rearc_quest_alb.dns_name
}

output "ecr_url" {
  value = aws_ecr_repository.repo.repository_url
}
