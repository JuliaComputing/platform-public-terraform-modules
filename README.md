# JuliaHub Platform Terraform Modules

Reusable Terraform modules for deploying the [JuliaHub](https://juliahub.com) platform on public cloud providers.

## Available Modules

| Cloud | Module | Description |
|-------|--------|-------------|
| Azure | [azure/](azure/) | Complete Azure infrastructure: AKS, PostgreSQL, Azure Files, Blob Storage, networking |
| AWS | [aws/](aws/) | Complete AWS infrastructure: EKS, VPC, RDS PostgreSQL, EFS, S3, and IAM for the platform, Karpenter, and the load balancer controller |

Both modules provision a cluster, a database, and shared storage. On AWS the cluster controllers (Karpenter, the load balancer controller) have no EKS managed add-on, so their IAM is created but the charts are installed with Helm — see [aws/README.md](aws/README.md) for what is left to you and how each output maps to a Helm value.

## Installation guides

These modules provision the infrastructure; the installation guides cover the
whole install, including the Helm values these outputs feed:

- [AWS (Helm)](https://help.juliahub.com/juliahub/stable/installation/aws_helm/)
- [Azure (Helm)](https://help.juliahub.com/juliahub/stable/installation/azure_helm/)

Start there if you are installing the platform for the first time.

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
