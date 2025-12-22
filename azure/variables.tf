variable "azure_subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Networking variables
variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
  default     = "juliahub-vnet"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "postgresql_subnet_address_prefixes" {
  description = "Address prefixes for the PostgreSQL subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "private_endpoints_subnet_address_prefixes" {
  description = "Address prefixes for the private endpoints subnet"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}

# AKS variables
variable "aks_cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "aks_dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "aks_node_vm_size" {
  description = "VM size for AKS node pool"
  type        = string
  default     = "Standard_D4s_v6"
}

variable "aks_initial_node_count" {
  description = "Initial number of nodes in the AKS cluster"
  type        = number
  default     = 3
}

variable "aks_min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "aks_max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
}

variable "aks_os_disk_size_gb" {
  description = "OS disk size in GB for AKS nodes"
  type        = number
  default     = 128
}

# PostgreSQL variables
variable "postgresql_server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  type        = string
}

variable "postgresql_administrator_login" {
  description = "Administrator login for PostgreSQL"
  type        = string
  default     = "psqladmin"
}

variable "postgresql_sku_name" {
  description = "SKU name for PostgreSQL server"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "13"
}

variable "postgresql_storage_mb" {
  description = "Storage size in MB for PostgreSQL"
  type        = number
  default     = 32768
}

variable "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "juliahub"
}

variable "postgresql_backup_retention_days" {
  description = "Number of days to retain PostgreSQL backups"
  type        = number
  default     = 30
}

variable "postgresql_additional_extensions" {
  description = "Additional PostgreSQL extensions to enable (uuid-ossp and pg_trgm are always included)"
  type        = list(string)
  default     = []
}

# Azure Files variables
variable "files_storage_account_name" {
  description = "Name of the Azure Files storage account (must be globally unique)"
  type        = string
}

variable "files_replication_type" {
  description = "Replication type for Azure Files storage"
  type        = string
  default     = "LRS"
}

variable "file_share_names" {
  description = "List of file share names to create"
  type        = list(string)
  default     = ["juliahub-config"]
}

variable "file_share_quota_gb" {
  description = "Quota for each file share in GB"
  type        = number
  default     = 700
}

# Azure Blob variables
variable "blob_storage_account_name" {
  description = "Name of the Azure Blob storage account (must be globally unique)"
  type        = string
}

variable "blob_account_tier" {
  description = "Account tier for blob storage"
  type        = string
  default     = "Standard"
}

variable "blob_replication_type" {
  description = "Replication type for blob storage"
  type        = string
  default     = "LRS"
}

variable "blob_container_names" {
  description = "List of blob container names to create"
  type        = list(string)
  default     = ["data", "backups"]
}

variable "blob_enable_versioning" {
  description = "Enable blob versioning"
  type        = bool
  default     = false
}

variable "blob_delete_retention_days" {
  description = "Number of days to retain deleted blobs"
  type        = number
  default     = 7
}

variable "blob_container_delete_retention_days" {
  description = "Number of days to retain deleted containers"
  type        = number
  default     = 7
}
