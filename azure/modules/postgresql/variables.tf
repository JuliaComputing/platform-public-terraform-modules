variable "server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  type        = string
}

variable "location" {
  description = "Azure region where the server will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "administrator_login" {
  description = "Administrator login for the PostgreSQL server"
  type        = string
  default     = "psqladmin"
}

variable "administrator_password" {
  description = "Administrator password for the PostgreSQL server"
  type        = string
  sensitive   = true
}

variable "sku_name" {
  description = "SKU name for the PostgreSQL server (e.g., B_Standard_B2s for 2 vCore B-Series)"
  type        = string
  default     = "B_Standard_B2s"
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "13"
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
  default     = 32768
}

variable "storage_tier" {
  description = "Storage tier (P4, P6, P10, P15, P20, P30, P40, P50, P60, P70, P80)"
  type        = string
  default     = "P4"
}

variable "subnet_id" {
  description = "ID of the subnet for private access"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone"
  type        = string
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups"
  type        = bool
  default     = false
}

variable "zone" {
  description = "Availability zone for the server"
  type        = string
  default     = "1"
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
  default     = "juliahub"
}

variable "postgresql_additional_extensions" {
  description = "Additional PostgreSQL extensions to enable (uuid-ossp, pg_trgm, and pgcrypto are always included)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
