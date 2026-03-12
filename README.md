# JuliaHub Platform Terraform Modules

Reusable Terraform modules for deploying the [JuliaHub](https://juliahub.com) platform on public cloud providers.

## Available Modules

| Cloud | Module | Description |
|-------|--------|-------------|
| Azure | [azure/](azure/) | Complete Azure infrastructure: AKS, PostgreSQL, Azure Files, Blob Storage, networking |

## Usage

Each cloud module is a self-contained Terraform root module. See the README in the respective directory for prerequisites, configuration, and deployment instructions.

```bash
cd azure/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## License

Proprietary. Copyright JuliaHub, Inc.
