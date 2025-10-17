variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_name" {
  description = "Name of the AKS subnet"
  type        = string
  default     = "aks-subnet"
}

variable "aks_subnet_address_prefixes" {
  description = "Address prefixes for the AKS subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "postgresql_subnet_name" {
  description = "Name of the PostgreSQL subnet"
  type        = string
  default     = "postgresql-subnet"
}

variable "postgresql_subnet_address_prefixes" {
  description = "Address prefixes for the PostgreSQL subnet"
  type        = list(string)
  default     = ["10.0.2.0/24"]
}

variable "private_endpoints_subnet_name" {
  description = "Name of the private endpoints subnet"
  type        = string
  default     = "private-endpoints-subnet"
}

variable "private_endpoints_subnet_address_prefixes" {
  description = "Address prefixes for the private endpoints subnet"
  type        = list(string)
  default     = ["10.0.3.0/24"]
}

variable "aks_nsg_name" {
  description = "Name of the AKS Network Security Group"
  type        = string
  default     = "aks-nsg"
}

variable "postgresql_nsg_name" {
  description = "Name of the PostgreSQL Network Security Group"
  type        = string
  default     = "postgresql-nsg"
}

variable "private_endpoints_nsg_name" {
  description = "Name of the private endpoints Network Security Group"
  type        = string
  default     = "private-endpoints-nsg"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
