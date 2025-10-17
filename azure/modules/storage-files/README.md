# Azure Files Storage Module

This module creates an Azure Storage Account with Premium File shares for JuliaHub Platform, configured with private endpoint access.

## Features

- **Premium File Storage**: High-performance file shares with low latency
- **Private Endpoint**: Secure access via VNet integration
- **SMB Protocol**: Standard SMB file sharing
- **Network Security**: Public access disabled, VNet service endpoints configured
- **Pre-created File Shares**: Automatically creates specified file shares

## Default Configuration

- **Account Tier**: Premium
- **Account Kind**: FileStorage (dedicated for file shares)
- **Replication**: LRS (Locally Redundant Storage)
- **Protocol**: SMB
- **Default Share**: juliahub-config (100 GB)
- **TLS Version**: 1.2 minimum

## Usage

```hcl
module "storage_files" {
  source = "./modules/storage-files"

  storage_account_name = "juliahubfiles"  # Must be globally unique
  location             = "eastus"
  resource_group_name  = azurerm_resource_group.main.name

  file_share_names    = ["juliahub-config"]
  file_share_quota_gb = 100

  allowed_subnet_ids = [
    module.networking.aks_subnet_id
  ]

  private_endpoint_subnet_id = module.networking.private_endpoints_subnet_id
  private_dns_zone_id        = module.networking.file_private_dns_zone_id

  tags = {
    Environment = "test"
    Project     = "juliahub"
  }
}
```

## Kubernetes Integration

The module outputs several Kubernetes resource templates:

### 1. StorageClass

```bash
terraform output -raw storage_files_kubernetes_storage_class_yaml | kubectl apply -f -
```

### 2. Secret (for storage account credentials)

```bash
# Create secret with storage account key
kubectl create secret generic azure-files-secret \
  --from-literal=azurestorageaccountname=$(terraform output -raw storage_files_storage_account_name) \
  --from-literal=azurestorageaccountkey=$(terraform output -raw storage_files_primary_access_key)
```

### 3. PersistentVolume and PersistentVolumeClaim

```bash
terraform output -raw storage_files_kubernetes_pv_yaml | kubectl apply -f -
```

## Using the File Share in Pods

After applying the PV and PVC:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: juliahub-app
spec:
  containers:
  - name: app
    image: juliahub:latest
    volumeMounts:
    - name: config
      mountPath: /config
  volumes:
  - name: config
    persistentVolumeClaim:
      claimName: juliahub-config-pvc
```

## Storage Account Naming

Azure Storage Account names must be:
- Globally unique across all Azure
- 3-24 characters long
- Lowercase letters and numbers only
- No special characters or hyphens

## Requirements

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| storage_account_name | Storage account name (globally unique) | `string` | n/a | yes |
| location | Azure region | `string` | n/a | yes |
| resource_group_name | Resource group name | `string` | n/a | yes |
| private_endpoint_subnet_id | Subnet ID for private endpoint | `string` | n/a | yes |
| private_dns_zone_id | Private DNS zone ID | `string` | n/a | yes |
| replication_type | Replication type (LRS or ZRS) | `string` | `"LRS"` | no |
| file_share_names | List of file share names | `list(string)` | `["juliahub-config"]` | no |
| file_share_quota_gb | Quota per share in GB | `number` | `100` | no |
| allowed_subnet_ids | Subnet IDs allowed access | `list(string)` | `[]` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| storage_account_id | Storage account ID |
| storage_account_name | Storage account name |
| primary_file_endpoint | Primary file endpoint |
| primary_access_key | Primary access key (sensitive) |
| file_share_names | Created file share names |
| file_share_urls | File share URLs |
| kubernetes_storage_class_yaml | StorageClass YAML |
| kubernetes_secret_yaml | Secret YAML template (sensitive) |
| kubernetes_pv_yaml | PersistentVolume and PVC YAML |

## Access from Outside Kubernetes

The file share can be mounted directly on VMs within the VNet:

```bash
# Linux/macOS
sudo mount -t cifs //<storage-account>.file.core.windows.net/juliahub-config \
  /mnt/juliahub-config \
  -o username=<storage-account>,password=<key>,serverino
```
