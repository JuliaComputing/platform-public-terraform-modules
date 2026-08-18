# ACM Certificate Module

Issues an ACM certificate for the platform hostname and validates it over DNS.

## When you need this

The platform is served through an ALB, which terminates TLS with an ACM certificate. The certificate ARN goes on the chart's ingress annotation, and the AWS Load Balancer Controller attaches it to the listener.

**This module is optional.** It only helps when the parent zone is a Route 53 hosted zone in an account this terraform can reach. If any of the following apply, skip it and pass an ARN to the root module's `certificate_arn` input instead:

- DNS is hosted outside Route 53, or in an account terraform cannot reach
- Certificates come from an internal CA and are imported into ACM
- Your organisation issues certificates through a separate process

The root module takes `certificate_arn` as a plain string precisely so that none of those cases require this module.

## Usage

```hcl
provider "aws" {
  region = "us-east-1"
}

module "certificate" {
  source = "./modules/acm-certificate"

  domain_name       = "juliahub.example.com"
  route53_zone_name = "example.com"

  providers = {
    aws         = aws
    aws.route53 = aws
  }

  tags = {
    Environment = "production"
  }
}

module "juliahub" {
  source = "./"

  cluster_name    = "juliahub"
  certificate_arn = module.certificate.certificate_arn
}
```

## The `aws.route53` provider alias

The module takes two provider configurations so the hosted zone can live in a different AWS account from the certificate. When they are in the same account, which is the usual case, point both at the same provider as above.

For a split-account setup, alias a second provider at the DNS account:

```hcl
provider "aws" {
  alias  = "dns"
  region = "us-east-1"
  assume_role { role_arn = "arn:aws:iam::111122223333:role/DNSAdmin" }
}

module "certificate" {
  # ...
  providers = {
    aws         = aws
    aws.route53 = aws.dns
  }
}
```

## What gets covered

By default the certificate covers three names:

| Name | Why |
|------|-----|
| `<domain_name>` | The platform itself |
| `docs.<domain_name>` | Generated package documentation |
| `*.apps.<domain_name>` | User applications, each on its own subdomain |

Override with `additional_sans` if your layout differs. Dropping the wildcard means user applications will not load over TLS — the platform comes up fine and only apps fail, so it is worth keeping unless you know you do not need it.

## Validating out of band

Set `create_route53_validation_records = false` to have the certificate created but not validated here. You then publish the validation records yourself.

Note that `certificate_arn` is returned as soon as the certificate exists, before it is issued. Attaching a pending certificate to a listener fails, so do not wire the output straight into an ALB in this mode — validate first, then apply.

With the default of `true`, the output depends on `aws_acm_certificate_validation`, so consumers wait until the certificate is genuinely usable.

## Inputs

| Variable | Default | Description |
|----------|---------|-------------|
| `domain_name` | — | Primary domain, the hostname users load the platform from |
| `route53_zone_name` | `""` | Hosted zone holding `domain_name`, required when creating validation records |
| `additional_sans` | `docs.` + `*.apps.` | Subject alternative names |
| `create_route53_validation_records` | `true` | Whether to publish validation records and wait for issuance |
| `tags` | `{}` | Tags for the certificate |

## Outputs

| Output | Description |
|--------|-------------|
| `certificate_arn` | Certificate ARN, for the root module's `certificate_arn` input |
| `domain_name` | Primary domain covered |
| `subject_alternative_names` | SANs covered |
