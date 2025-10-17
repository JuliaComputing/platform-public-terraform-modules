# Networking Module

This module creates the networking infrastructure for JuliaHub Platform on Azure, including:

- Virtual Network (VNet)
- Subnets for AKS, PostgreSQL, and private endpoints
- Network Security Groups (NSGs) with security rules
- Private DNS zones for private endpoints

## Features

- **VNet**: Creates a virtual network with configurable address space
- **Subnets**:
  - AKS subnet with service endpoints for storage
  - PostgreSQL subnet with delegation for Flexible Server
  - Private endpoints subnet for storage account private endpoints
- **NSGs**: Security groups with rules allowing:
  - HTTP/HTTPS traffic to AKS subnet
  - AKS to PostgreSQL communication on port 5432
  - AKS to private endpoints communication
- **Private DNS Zones**: For PostgreSQL, Blob Storage, and File Storage private endpoints

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  vnet_name           = "juliahub-vnet"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.main.name

  vnet_address_space                       = ["10.0.0.0/16"]
  aks_subnet_address_prefixes              = ["10.0.1.0/24"]
  postgresql_subnet_address_prefixes       = ["10.0.2.0/24"]
  private_endpoints_subnet_address_prefixes = ["10.0.3.0/24"]

  tags = {
    Environment = "test"
    Project     = "juliahub"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| vnet_name | Name of the Virtual Network | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| vnet_address_space | VNet address space | `list(string)` | `["10.0.0.0/16"]` | no |
| aks_subnet_address_prefixes | AKS subnet address prefixes | `list(string)` | `["10.0.1.0/24"]` | no |
| postgresql_subnet_address_prefixes | PostgreSQL subnet address prefixes | `list(string)` | `["10.0.2.0/24"]` | no |
| private_endpoints_subnet_address_prefixes | Private endpoints subnet address prefixes | `list(string)` | `["10.0.3.0/24"]` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | ID of the Virtual Network |
| vnet_name | Name of the Virtual Network |
| aks_subnet_id | ID of the AKS subnet |
| postgresql_subnet_id | ID of the PostgreSQL subnet |
| private_endpoints_subnet_id | ID of the private endpoints subnet |
| postgres_private_dns_zone_id | ID of the PostgreSQL private DNS zone |
| blob_private_dns_zone_id | ID of the Blob Storage private DNS zone |
| file_private_dns_zone_id | ID of the File Storage private DNS zone |
