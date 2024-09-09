terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.65.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.aws_region
  shared_credentials_files = terraform.workspace == "local" ? [  ] : ["~/.aws/credentials"]
}

################
## S3 bucket ##
################
module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.1.2"
  
}

resource "aws_s3_bucket" "frontend" {
  bucket        = var.s3_bucket_name #weupliftnyc-org
  force_destroy = true
}

resource "aws_s3_bucket_acl" "acl_frontend" {
  bucket = aws_s3_bucket.frontend.id
  acl    = "public-read" 
}

resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["Authorization", "Content-Length"]
    allowed_methods = ["GET", "POST"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}

data "aws_iam_policy_document" "public_bucket_access" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
  }
}

resource "null_resource" "update_source_files" {
    provisioner "local-exec" {
        command     = "aws${terraform.workspace == "local"? "local" : ""} s3 sync ../out s3://${aws_s3_bucket.frontend.bucket}" 
    }
}

################
## cloudfront ##
################

locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = local.s3_origin_id
  }

  default_root_object = "index.html"

  enabled = true
  is_ipv6_enabled = true
  comment = "Some comment"

  logging_config {
    include_cookies = false
    bucket = "mylogs.s3.amazonaws.com"
    prefix = "myprefix"
  }

  aliases = [ "weupliftnyc.org.local" ]

  default_cache_behavior {
    allowed_methods = [ "DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT" ]
    cached_methods = [ "GET", "HEAD" ]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl = 0
    default_ttl = 3600
    max_ttl = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

}

##############
## Route53 ##
##############
locals {
  hosted_zone_with_workspace = terraform.workspace == "prod" ? var.domain_name_route53 : "${terraform.workspace}.${var.domain_name_route53}"
}
resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name_route53
}

resource "aws_route53_record" "www" {
  zone_id         = aws_route53_zone.hosted_zone.zone_id
  name    = terraform.workspace == "prod" ? "www" : "www.${terraform.workspace}"
  type    = "A"

  alias {
     name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }

}

resource "aws_route53_record" "base_domain" {
  zone_id         = aws_route53_zone.hosted_zone.zone_id
  name    =  terraform.workspace == "prod" ? ""   : terraform.workspace
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }

}

resource "aws_acm_certificate" "cert" {
  domain_name       =  var.domain_name_route53
  validation_method = "DNS"

  subject_alternative_names =  ["www.${local.hosted_zone_with_workspace}", local.hosted_zone_with_workspace]
  tags = {
    Name = "${var.s3_bucket_name}-cert"
    Domain=  var.domain_name_route53
    Environment = terraform.workspace
    Application = var.s3_bucket_name
  }

}

resource "aws_acm_certificate_validation" "cert-validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.site_domain : record.fqdn]
}


resource "aws_route53_record" "site_domain" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options  : dvo.domain_name => {
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
  zone_id         = aws_route53_zone.hosted_zone.zone_id
}
