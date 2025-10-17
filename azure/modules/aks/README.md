# AKS Module

This module creates an Azure Kubernetes Service (AKS) cluster configured for hosting JuliaHub Platform.

## Features

- **Azure CNI Overlay networking**: Modern overlay network mode for improved scalability
- **Standard Load Balancer**: Production-grade load balancing
- **Virtual Machine Scale Sets**: For node pools with autoscaling support
- **Autoscaling**: Automatically scales between min and max node counts based on demand
- **Storage Drivers**:
  - Azure Disk CSI Driver (v2) for persistent volumes
  - Azure File CSI Driver for shared file storage
  - Azure Blob CSI Driver for blob storage
- **Web App Routing**: Azure Application Gateway for Containers integration
- **System-assigned managed identity**: For secure Azure resource access

## Default Configuration

- **Kubernetes Version**: 1.33
- **Node VM Size**: Standard_D4s_v6 (4 vCPU, 16 GB RAM)
- **Initial Node Count**: 3 nodes
- **Autoscaling Range**: 3-10 nodes
- **OS Disk**: 128 GB
- **Total Resources**: 12 vCPU, 48 GB RAM (meets 8 core/30GB requirement with headroom)

## Usage

```hcl
module "aks" {
  source = "./modules/aks"

  cluster_name        = "juliahub-aks"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "juliahub"

  subnet_id = module.networking.aks_subnet_id
  vnet_id   = module.networking.vnet_id

  kubernetes_version  = "1.33"
  node_vm_size        = "Standard_D4s_v6"
  initial_node_count  = 3
  min_node_count      = 3
  max_node_count      = 10

  tags = {
    Environment = "test"
    Project     = "juliahub"
  }
}
```

## Storage Classes

The module outputs YAML configurations for storage classes that can be applied to your cluster:

- `azure-disk-premium`: Premium SSD managed disks
- `azure-disk-standard`: Standard SSD managed disks
- `azure-blob`: Azure Blob storage

Apply them with:
```bash
echo "${module.aks.storage_classes_yaml.azure_disk_premium}" | kubectl apply -f -
echo "${module.aks.storage_classes_yaml.azure_disk_standard}" | kubectl apply -f -
echo "${module.aks.storage_classes_yaml.azure_blob}" | kubectl apply -f -
```

## Requirements

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the AKS cluster | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| dns_prefix | DNS prefix for the cluster | `string` | n/a | yes |
| subnet_id | ID of the subnet for AKS nodes | `string` | n/a | yes |
| vnet_id | ID of the Virtual Network | `string` | n/a | yes |
| kubernetes_version | Kubernetes version | `string` | `"1.33"` | no |
| node_vm_size | VM size for node pool | `string` | `"Standard_D4s_v6"` | no |
| initial_node_count | Initial number of nodes | `number` | `3` | no |
| min_node_count | Minimum nodes for autoscaling | `number` | `3` | no |
| max_node_count | Maximum nodes for autoscaling | `number` | `10` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster_id | ID of the AKS cluster |
| cluster_name | Name of the AKS cluster |
| cluster_fqdn | FQDN of the AKS cluster |
| kube_config | Kubernetes configuration (sensitive) |
| kubelet_identity | Kubelet identity object |
| cluster_identity_principal_id | Principal ID of the cluster identity |
| storage_classes_yaml | YAML configurations for storage classes |

## Connecting to the Cluster

```bash
az aks get-credentials --resource-group <resource-group-name> --name <cluster-name>
kubectl get nodes
```
