resource "aws_acm_certificate" "cert" {
  domain_name       = "${var.prefix}.${data.aws_route53_zone.r53_zone.name}"
  validation_method = "DNS"

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.r53_zone.zone_id
  name    = "${var.prefix}.${data.aws_route53_zone.r53_zone.name}"
  type    = "CNAME"
  ttl     = "300"
  records = [ aws_alb.rearc_quest_ecs_lb.dns_name ]
}

resource "aws_route53_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.r53_zone.zone_id
}

resource "aws_acm_certificate_validation" "validate" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}
