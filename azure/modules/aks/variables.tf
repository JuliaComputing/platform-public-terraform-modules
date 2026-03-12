variable "cluster_name" {
  description = "Name of the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region where the cluster will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.33"
}

variable "subnet_id" {
  description = "ID of the subnet for AKS nodes"
  type        = string
}

variable "vnet_id" {
  description = "ID of the Virtual Network"
  type        = string
}

variable "node_vm_size" {
  description = "VM size for the node pool"
  type        = string
  default     = "Standard_D4s_v6"
}

variable "initial_node_count" {
  description = "Initial number of nodes"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 10
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 128
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

variable "additional_node_pools" {
  description = "Map of additional node pools to create alongside the default system pool"
  type = map(object({
    vm_size            = string
    min_count          = optional(number, 0)
    max_count          = optional(number, 10)
    initial_node_count = optional(number, 0)
    os_disk_size_gb    = optional(number, 128)
    node_labels        = optional(map(string), {})
    node_taints        = optional(list(string), [])
    mode               = optional(string, "User")
  }))
  default = {
    large = {
      vm_size = "Standard_D8s_v6"
    }
    xlarge = {
      vm_size = "Standard_D16s_v6"
    }
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
