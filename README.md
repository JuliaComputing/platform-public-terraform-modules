# JuliaHub Platform Terraform Modules

Reusable Terraform modules for deploying the [JuliaHub](https://juliahub.com) platform on public cloud providers.

## Available Modules

| Cloud | Module | Description |
|-------|--------|-------------|
| Azure | [azure/](azure/) | Complete Azure infrastructure: AKS, PostgreSQL, Azure Files, Blob Storage, networking |
| AWS | [aws/](aws/) | Complete AWS infrastructure: EKS, VPC, RDS PostgreSQL, S3, compute IAM roles |

Both modules provision a cluster, a database, and object storage. EFS and ingress are still provisioned separately on AWS — see [aws/README.md](aws/README.md) for the list and how each maps to a Helm value.

## Usage

Each cloud module is a self-contained Terraform root module. See the README in the respective directory for prerequisites, configuration, and deployment instructions.

```bash
cd aws/    # or azure/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## Versioning

These modules are consumed by git ref. Pin to a tag rather than tracking a branch:

```hcl
module "juliahub" {
  source = "git::https://github.com/JuliaComputing/platform-public-terraform-modules.git//aws?ref=v0.1.0"
  # ...
}
```

Each release notes the JuliaHub platform chart versions it has been validated against.

## License

Proprietary. Copyright JuliaHub, Inc.
