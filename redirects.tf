# Variables
variable "fqdn" {
  description = "The fully-qualified domain name root of the resulting S3 website."
  default     = "{{REDIRECT_SOURCE}}"
}

variable "redirect_target" {
  description = "The fully-qualified domain name to redirect to."
  default     = "{{REDIRECT_TARGET}}"
}

# DEFUALT AWS SETUP
provider "aws" {
  region = "us-east-1"
  access_key = "{{AWS_ACCESS_KEY}}"
  secret_key = "{{AWS_ACCESS_SECRET}}"
}

# AWS Region for S3 and other resources
provider "aws" {
  region = "us-west-2"
  alias = "main"
  access_key = "{{AWS_ACCESS_KEY}}"
  secret_key = "{{AWS_ACCESS_SECRET}}"
}

# AWS Region for Cloudfront (ACM certs only supports us-east-1)
provider "aws" {
  region = "us-east-1"
  alias = "cloudfront"
  access_key = "{{AWS_ACCESS_KEY}}"
  secret_key = "{{AWS_ACCESS_SECRET}}"
}

# Using this module
module "main" {
  source = "github.com/riboseinc/terraform-aws-s3-cloudfront-redirect"

  fqdn = "${var.fqdn}"
  redirect_target = "${var.redirect_target}"
  ssl_certificate_arn = "${aws_acm_certificate_validation.cert.certificate_arn}"

  refer_secret = "${base64sha512("REFER-SECRET-19265125-${var.fqdn}-52865926")}"
  force_destroy = "true"

  providers = {
    aws.main = aws.main
    aws.cloudfront = aws.cloudfront
  }

  # Optional WAF Web ACL ID, defaults to none.
  #web_acl_id = "${data.terraform_remote_state.site.waf-web-acl-id}"
}

# ACM Certificate generation

resource "aws_acm_certificate" "cert" {
  provider          = aws.cloudfront
  domain_name       = "${var.fqdn}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "cert" {
  provider          = aws.main
  name         = "${var.fqdn}"
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  provider          = aws.main
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
  zone_id         = data.aws_route53_zone.cert.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}


# Route 53 record for the static site

data "aws_route53_zone" "main" {
  provider     = aws.main
  name         = "${var.fqdn}"
  private_zone = false
}

resource "aws_route53_record" "web" {
  provider = aws.main
  zone_id  = "${data.aws_route53_zone.main.zone_id}"
  name     = "${var.fqdn}"
  type     = "A"
  allow_overwrite = true

  alias {
    name    = "${module.main.cf_domain_name}"
    zone_id = "${module.main.cf_hosted_zone_id}"
    evaluate_target_health = false
  }
}

# Outputs

output "s3_bucket_id" {
  value = "${module.main.s3_bucket_id}"
}

output "s3_domain" {
  value = "${module.main.s3_website_endpoint}"
}

output "s3_hosted_zone_id" {
  value = "${module.main.s3_hosted_zone_id}"
}

output "cloudfront_domain" {
  value = "${module.main.cf_domain_name}"
}

output "cloudfront_hosted_zone_id" {
  value = "${module.main.cf_hosted_zone_id}"
}

output "cloudfront_distribution_id" {
  value = "${module.main.cf_distribution_id}"
}

output "route53_fqdn" {
  value = "${aws_route53_record.web.fqdn}"
}

output "acm_certificate_arn" {
  value = "${aws_acm_certificate_validation.cert.certificate_arn}"
}
