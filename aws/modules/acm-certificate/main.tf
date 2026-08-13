# ACM certificate for the platform hostname, validated over DNS.
#
# Only useful when the parent zone is hosted in Route 53 in an account this
# terraform can reach. If your DNS lives elsewhere, or your certificates come
# from an internal CA, skip this module and pass the certificate ARN directly
# to the root module's certificate_arn input.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
      # aws.route53 lets the hosted zone live in a different account from the
      # certificate. Point it at the same provider when they are colocated,
      # which is the common case.
      configuration_aliases = [aws, aws.route53]
    }
  }
}

variable "domain_name" {
  description = "Primary domain the certificate is issued for. This is the hostname users load the platform from, e.g. juliahub.example.com."
  type        = string
}

variable "route53_zone_name" {
  description = "Name of the Route 53 hosted zone holding domain_name, e.g. example.com. Only used when create_route53_validation_records is true."
  type        = string
  default     = ""
}

variable "additional_sans" {
  description = <<-EOT
    Subject alternative names beyond domain_name.

    Defaults to docs.<domain_name> and *.apps.<domain_name>, which the platform
    serves generated documentation and user applications from respectively.
    Dropping the wildcard means apps will not load over TLS.
  EOT
  type        = list(string)
  default     = null
}

variable "create_route53_validation_records" {
  description = "Whether to create the DNS validation records and wait for the certificate to be issued. Set false to have the certificate created but validated out of band, in which case the ARN is returned before the certificate is usable."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to the certificate"
  type        = map(string)
  default     = {}
}

locals {
  default_sans = [
    "docs.${var.domain_name}",
    "*.apps.${var.domain_name}",
  ]

  sans = var.additional_sans != null ? var.additional_sans : local.default_sans
}

resource "aws_acm_certificate" "_" {
  domain_name               = var.domain_name
  subject_alternative_names = local.sans
  validation_method         = "DNS"

  tags = merge(var.tags, {
    Name = var.domain_name
  })

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "_" {
  count = var.create_route53_validation_records ? 1 : 0

  provider = aws.route53
  name     = var.route53_zone_name
}

resource "aws_route53_record" "validation" {
  # A certificate covering both example.com and *.example.com produces the same
  # validation record twice, so these are keyed by domain to deduplicate.
  for_each = var.create_route53_validation_records ? {
    for dvo in aws_acm_certificate._.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  provider = aws.route53

  zone_id         = data.aws_route53_zone._[0].zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "_" {
  count = var.create_route53_validation_records ? 1 : 0

  certificate_arn         = aws_acm_certificate._.arn
  validation_record_fqdns = [for record in aws_route53_record.validation : record.fqdn]
}

output "certificate_arn" {
  description = "ARN of the certificate. Pass this to the root module's certificate_arn input, which puts it on the ingress annotation."
  value       = aws_acm_certificate._.arn

  # Depending on the validation resource makes consumers wait for the
  # certificate to be issued rather than attaching a pending one to a listener.
  depends_on = [aws_acm_certificate_validation._]
}

output "domain_name" {
  description = "Primary domain the certificate covers"
  value       = aws_acm_certificate._.domain_name
}

output "subject_alternative_names" {
  description = "Subject alternative names the certificate covers"
  value       = aws_acm_certificate._.subject_alternative_names
}
