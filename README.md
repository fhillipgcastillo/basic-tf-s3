# Basic Terraform S3, CloudFront, and Route53 Configuration for Next.js
Just copy the `.infra` folder to the root of your Next.js project and run the following commands:


## Overview

This document explains the Terraform configuration for setting up a production-ready infrastructure for a Next.js project using AWS S3, CloudFront, and Route53. The configuration files are located in the `.infra` folder at the project root.


## Steps to download it to your next project
1. Clone the repository
```bash
git clone https://github.com/fhillipgcastillo/basic-tf-s3.git
or
git@github.com:fhillipgcastillo/basic-tf-s3.git
```
2. Get into the project
  ```bash
   cd basic-tf-s3
   ```
3. Copy the `.infra` folder to the root of your Next.js project
  ```bash
  cp -r .infra /path/to/your/nextjs/project
  ```
4. Get into the `.infra` folder
  ```bash
  cd /path/to/your/nextjs/project/.infra
  ```
5. Run terraform init
   **With terraform local**
   First run the localstack docker file
   ```bash
   docker compose -f docker-compose.local.yml up -d
   ```
   Then run the following command
   ```bash
   tflocal init
   tflocal apply
   ```
  Provide the requested variables and wait for the infrastructure to be created.
  **With terraform AWS**
  ```bash
  terraform init
  terraform apply
  ```

## 1. Variables ([variables.tf](variables.tf))

```
variable "s3_bucket_name" {
  description = "The name of the public files bucket"
  type        = string
}

variable "aws_region" {
  type        = string
  default     = "us-west-1"
  description = "aws region"
}

variable "domain_name_route53" {
  description = "The domain name of the website"
  type        = string
}
```

This block defines the input variables for the Terraform configuration, including the S3 bucket name, AWS region, and domain name for Route53.

## 2. Main Configuration ([main.tf](main.tf))

The main configuration file contains the following key components:

### 2.1 Provider Configuration

```
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
  shared_credentials_files = terraform.workspace == "local" ? [] : ["~/.aws/credentials"]
}
```

This section sets up the AWS provider and specifies the required Terraform version.

### 2.2 S3 Bucket Configuration

```
resource "aws_s3_bucket" "frontend" {
  bucket        = var.s3_bucket_name
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
```

This section creates an S3 bucket for hosting the Next.js application, sets its ACL to public-read, and configures CORS rules.

### 2.3 CloudFront Distribution

```
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
  }
  
  enabled             = true
  default_root_object = "index.html"
  
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }
  
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
```

This section sets up a CloudFront distribution to serve the S3 bucket content with improved performance and HTTPS support.

### 2.4 Route53 Configuration

```
resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name_route53
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = terraform.workspace == "prod" ? "www" : "www.${terraform.workspace}"
  type    = "A"
  
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
```

This section creates a Route53 hosted zone and sets up DNS records to point to the CloudFront distribution.

## 3. Outputs ([outputs.tf](outputs.tf))

```
output "s3_bucket_name" {
  value = aws_s3_bucket.frontend.bucket_domain_name
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

output "route53_nameservers" {
  value = aws_route53_zone.hosted_zone.name_servers
}
```

This file defines the outputs that will be displayed after applying the Terraform configuration, including the S3 bucket name, CloudFront domain, and Route53 nameservers.

## Conclusion

This Terraform configuration sets up a production-ready infrastructure for hosting a Next.js application on AWS, using S3 for storage, CloudFront for content delivery, and Route53 for DNS management. The configuration is modular and can be easily customized for different environments using Terraform workspaces.