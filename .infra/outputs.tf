output "s3_domain_name" {
  value = aws_s3_bucket.frontend.bucket_regional_domain_name
}
output "s3_arn" {
  value = aws_s3_bucket.frontend.arn
}
output "s3_id" {
  value = aws_s3_bucket.frontend.id
}
output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket_domain_name
}

output "domain" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

# soute53
output "site_domain" {
  value = [for record in aws_route53_record.site_domain : record.fqdn]
}
output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}

output "certificate_domains" {
  value = aws_acm_certificate.cert.domain_validation_options
}
output "hosted_zone_id" {
  value = aws_route53_zone.hosted_zone.zone_id
}
output "domain_name" {
  value = var.domain_name_route53
  
}
output "dns_name_services" {
  value = aws_route53_zone.hosted_zone.name_servers
}
