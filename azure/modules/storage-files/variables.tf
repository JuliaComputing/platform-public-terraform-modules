variable "storage_account_name" {
  description = "Name of the storage account (must be globally unique, 3-24 lowercase alphanumeric)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 characters, lowercase alphanumeric only."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "replication_type" {
  description = "Storage replication type (LRS, ZRS for Premium)"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS"], var.replication_type)
    error_message = "Premium file shares only support LRS or ZRS replication."
  }
}

variable "file_share_names" {
  description = "List of file share names to create"
  type        = list(string)
  default     = ["juliahub-config", "juliahub-userdata"]
}

variable "file_share_quota_gb" {
  description = "Quota for each file share in GB"
  type        = number
  default     = 100
}

variable "allowed_subnet_ids" {
  description = "List of subnet IDs allowed to access the storage account"
  type        = list(string)
  default     = []
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID for the private endpoint"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for file storage"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
