# PostgreSQL Flexible Server Module

This module creates an Azure Database for PostgreSQL Flexible Server with private networking for JuliaHub Platform.

## Features

- **PostgreSQL Flexible Server**: Modern, fully managed PostgreSQL service
- **Private Access**: Integrated with VNet using delegated subnet
- **Automated Backups**: Configurable retention period (default: 30 days)
- **B-Series SKU**: Cost-effective burstable compute for test/dev workloads
- **Encryption at Rest**: Enabled by default with Azure-managed keys

## Default Configuration

- **SKU**: B_Standard_B2s (2 vCores, burstable)
- **PostgreSQL Version**: 13
- **Storage**: 32 GB (P4 tier)
- **Backup Retention**: 30 days
- **Geo-redundant Backup**: Disabled (can be enabled)
- **Default Database**: juliahub

## Usage

```hcl
module "postgresql" {
  source = "./modules/postgresql"

  server_name         = "juliahub-postgres"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.main.name

  administrator_login    = "psqladmin"
  administrator_password = var.postgresql_password

  subnet_id           = module.networking.postgresql_subnet_id
  private_dns_zone_id = module.networking.postgres_private_dns_zone_id

  database_name           = "juliahub"
  backup_retention_days   = 30

  tags = {
    Environment = "test"
    Project     = "juliahub"
  }
}
```

## Kubernetes Integration

The module outputs a Kubernetes Secret YAML template for easy integration:

```bash
# Output the secret template
terraform output -raw postgresql_kubernetes_secret_yaml > postgresql-secret.yaml

# Update the password field in the YAML file
# Then apply to your cluster
kubectl apply -f postgresql-secret.yaml
```

Or create the secret directly:

```bash
kubectl create secret generic postgresql-connection \
  --from-literal=host=$(terraform output -raw postgresql_server_fqdn) \
  --from-literal=port=5432 \
  --from-literal=database=$(terraform output -raw postgresql_database_name) \
  --from-literal=username=$(terraform output -raw postgresql_administrator_login) \
  --from-literal=password='YOUR_PASSWORD_HERE'
```

## Security Notes

- The server is only accessible via private endpoint within the VNet
- Administrator password must be provided via variable (use environment variables or secure vaults)
- SSL/TLS is enforced for all connections
- Store the administrator password securely (Azure Key Vault, HashiCorp Vault, etc.)

## Requirements

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| server_name | Name of the PostgreSQL Flexible Server | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| administrator_password | Administrator password | `string` | n/a | yes |
| subnet_id | ID of the delegated subnet | `string` | n/a | yes |
| private_dns_zone_id | ID of the private DNS zone | `string` | n/a | yes |
| administrator_login | Administrator login | `string` | `"psqladmin"` | no |
| sku_name | SKU name | `string` | `"B_Standard_B2s"` | no |
| postgresql_version | PostgreSQL version | `string` | `"16"` | no |
| storage_mb | Storage size in MB | `number` | `32768` | no |
| backup_retention_days | Backup retention in days | `number` | `30` | no |
| database_name | Database name | `string` | `"juliahub"` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| server_id | ID of the PostgreSQL server |
| server_name | Name of the PostgreSQL server |
| server_fqdn | FQDN of the PostgreSQL server |
| database_name | Name of the database |
| administrator_login | Administrator login (sensitive) |
| connection_string | Connection string (sensitive) |
| kubernetes_secret_yaml | Kubernetes Secret YAML template (sensitive) |

## Connecting to the Database

From within the VNet (using PostgreSQL 13 client):

```bash
psql "host=<server-fqdn> port=5432 dbname=juliahub user=psqladmin password=<password> sslmode=require"
```
