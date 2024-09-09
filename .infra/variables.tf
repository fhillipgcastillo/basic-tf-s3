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
