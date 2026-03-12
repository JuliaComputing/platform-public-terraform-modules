# Resource Group outputs
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

# Networking outputs
output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = module.networking.vnet_id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = module.networking.vnet_name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = module.networking.aks_subnet_id
}

# AKS outputs
output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = module.aks.cluster_id
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "aks_kube_config" {
  description = "Kubernetes configuration for AKS cluster"
  value       = module.aks.kube_config
  sensitive   = true
}

output "aks_storage_classes_yaml" {
  description = "YAML configurations for AKS storage classes"
  value       = module.aks.storage_classes_yaml
}

# PostgreSQL outputs
output "postgresql_server_id" {
  description = "ID of the PostgreSQL server"
  value       = module.postgresql.server_id
}

output "postgresql_server_name" {
  description = "Name of the PostgreSQL server"
  value       = module.postgresql.server_name
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = module.postgresql.server_fqdn
}

output "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  value       = module.postgresql.database_name
}

output "postgresql_administrator_login" {
  description = "Administrator login for PostgreSQL"
  value       = module.postgresql.administrator_login
  sensitive   = true
}

output "postgresql_administrator_password" {
  description = "Administrator password for PostgreSQL"
  value       = random_password.postgresql.result
  sensitive   = true
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string"
  value       = module.postgresql.connection_string
  sensitive   = true
}

output "postgresql_kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for PostgreSQL"
  value       = module.postgresql.kubernetes_secret_yaml
  sensitive   = true
}

# Azure Files outputs
output "storage_files_account_id" {
  description = "ID of the Azure Files storage account"
  value       = module.storage_files.storage_account_id
}

output "storage_files_account_name" {
  description = "Name of the Azure Files storage account"
  value       = module.storage_files.storage_account_name
}

output "storage_files_primary_access_key" {
  description = "Primary access key for Azure Files storage account"
  value       = module.storage_files.primary_access_key
  sensitive   = true
}

output "storage_files_share_names" {
  description = "Names of the created file shares"
  value       = module.storage_files.file_share_names
}

output "storage_files_kubernetes_storage_class_yaml" {
  description = "Kubernetes StorageClass YAML for Azure Files"
  value       = module.storage_files.kubernetes_storage_class_yaml
}

output "storage_files_kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for Azure Files"
  value       = module.storage_files.kubernetes_secret_yaml
  sensitive   = true
}

output "storage_files_server" {
  description = "Private link server address for the Azure Files storage account"
  value       = module.storage_files.storage_account_server
}

# Azure Blob outputs
output "storage_blob_account_id" {
  description = "ID of the Azure Blob storage account"
  value       = module.storage_blob.storage_account_id
}

output "storage_blob_account_name" {
  description = "Name of the Azure Blob storage account"
  value       = module.storage_blob.storage_account_name
}

output "storage_blob_primary_access_key" {
  description = "Primary access key for Azure Blob storage account"
  value       = module.storage_blob.primary_access_key
  sensitive   = true
}

output "storage_blob_primary_connection_string" {
  description = "Primary connection string for Azure Blob storage"
  value       = module.storage_blob.primary_connection_string
  sensitive   = true
}

output "storage_blob_container_names" {
  description = "Names of the created blob containers"
  value       = module.storage_blob.container_names
}

output "storage_blob_kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for Azure Blob"
  value       = module.storage_blob.kubernetes_secret_yaml
  sensitive   = true
}

output "storage_blob_kubernetes_storage_class_yaml" {
  description = "Kubernetes StorageClass YAML for Azure Blob"
  value       = module.storage_blob.kubernetes_storage_class_yaml
}

# Summary output
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    resource_group = azurerm_resource_group.main.name
    location       = azurerm_resource_group.main.location
    aks_cluster    = module.aks.cluster_name
    aks_fqdn       = module.aks.cluster_fqdn
    postgresql     = module.postgresql.server_fqdn
    database       = module.postgresql.database_name
    file_shares    = module.storage_files.file_share_names
    blob_containers = module.storage_blob.container_names
  }
}
