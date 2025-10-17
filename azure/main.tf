terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.azure_subscription_id

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
      Project   = "JuliaHub"
    }
  )
}

module "networking" {
  source = "./modules/networking"

  vnet_name           = var.vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  vnet_address_space                        = var.vnet_address_space
  aks_subnet_address_prefixes               = var.aks_subnet_address_prefixes
  postgresql_subnet_address_prefixes        = var.postgresql_subnet_address_prefixes
  private_endpoints_subnet_address_prefixes = var.private_endpoints_subnet_address_prefixes

  tags = local.common_tags
}

module "aks" {
  source = "./modules/aks"

  cluster_name        = var.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.aks_dns_prefix

  subnet_id = module.networking.aks_subnet_id
  vnet_id   = module.networking.vnet_id

  kubernetes_version = var.kubernetes_version
  node_vm_size       = var.aks_node_vm_size
  initial_node_count = var.aks_initial_node_count
  min_node_count     = var.aks_min_node_count
  max_node_count     = var.aks_max_node_count
  os_disk_size_gb    = var.aks_os_disk_size_gb

  tags = local.common_tags

  depends_on = [module.networking]
}

resource "random_password" "postgresql" {
  length  = 32
  special = true
}

module "postgresql" {
  source = "./modules/postgresql"

  server_name         = var.postgresql_server_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  administrator_login    = var.postgresql_administrator_login
  administrator_password = random_password.postgresql.result

  sku_name           = var.postgresql_sku_name
  postgresql_version = var.postgresql_version
  storage_mb         = var.postgresql_storage_mb

  subnet_id           = module.networking.postgresql_subnet_id
  private_dns_zone_id = module.networking.postgres_private_dns_zone_id

  database_name         = var.postgresql_database_name
  backup_retention_days = var.postgresql_backup_retention_days
  postgresql_extensions = var.postgresql_extensions

  tags = local.common_tags

  depends_on = [module.networking]
}

module "storage_files" {
  source = "./modules/storage-files"

  storage_account_name = var.files_storage_account_name
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name

  replication_type    = var.files_replication_type
  file_share_names    = var.file_share_names
  file_share_quota_gb = var.file_share_quota_gb

  allowed_subnet_ids = [
    module.networking.aks_subnet_id
  ]

  private_endpoint_subnet_id = module.networking.private_endpoints_subnet_id
  private_dns_zone_id        = module.networking.file_private_dns_zone_id

  tags = local.common_tags

  depends_on = [module.networking]
}

module "storage_blob" {
  source = "./modules/storage-blob"

  storage_account_name = var.blob_storage_account_name
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name

  account_tier     = var.blob_account_tier
  replication_type = var.blob_replication_type
  container_names  = var.blob_container_names

  enable_versioning               = var.blob_enable_versioning
  blob_delete_retention_days      = var.blob_delete_retention_days
  container_delete_retention_days = var.blob_container_delete_retention_days

  allowed_subnet_ids = [
    module.networking.aks_subnet_id
  ]

  private_endpoint_subnet_id = module.networking.private_endpoints_subnet_id
  private_dns_zone_id        = module.networking.blob_private_dns_zone_id

  tags = local.common_tags

  depends_on = [module.networking]
}
