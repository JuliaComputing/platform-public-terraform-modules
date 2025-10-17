# Azure Blob Storage Module

This module creates an Azure Storage Account for blob storage with private endpoint access for JuliaHub Platform.

## Features

- **Blob Storage**: Standard storage account optimized for blob storage
- **Private Endpoint**: Secure access via VNet integration
- **Data Protection**: Configurable blob and container soft delete
- **Network Security**: Public access disabled, VNet service endpoints configured
- **Pre-created Containers**: Automatically creates specified blob containers
- **Versioning Support**: Optional blob versioning for data protection

## Default Configuration

- **Account Tier**: Standard
- **Account Kind**: StorageV2 (General Purpose v2)
- **Replication**: LRS (Locally Redundant Storage)
- **Default Containers**: data, backups
- **TLS Version**: 1.2 minimum
- **HTTPS Only**: Enabled
- **Soft Delete**: 7 days retention for blobs and containers

## Usage

```hcl
module "storage_blob" {
  source = "./modules/storage-blob"

  storage_account_name = "juliahubblob"  # Must be globally unique
  location             = "eastus"
  resource_group_name  = azurerm_resource_group.main.name

  account_tier     = "Standard"
  replication_type = "LRS"

  container_names = ["data", "backups", "logs"]

  allowed_subnet_ids = [
    module.networking.aks_subnet_id
  ]

  private_endpoint_subnet_id = module.networking.private_endpoints_subnet_id
  private_dns_zone_id        = module.networking.blob_private_dns_zone_id

  enable_versioning              = false
  blob_delete_retention_days     = 7
  container_delete_retention_days = 7

  tags = {
    Environment = "test"
    Project     = "juliahub"
  }
}
```

## Kubernetes Integration

The module outputs Kubernetes resource templates:

### 1. Secret (for storage account credentials)

```bash
# Create secret with storage account key
kubectl create secret generic azure-blob-secret \
  --from-literal=azurestorageaccountname=$(terraform output -raw storage_blob_storage_account_name) \
  --from-literal=azurestorageaccountkey=$(terraform output -raw storage_blob_primary_access_key) \
  --from-literal=connection-string=$(terraform output -raw storage_blob_primary_connection_string)
```

### 2. StorageClass

The module provides two StorageClass options:

```bash
# Apply storage classes
terraform output -raw storage_blob_kubernetes_storage_class_yaml | kubectl apply -f -
```

- **azure-blob-nfs**: Uses NFS protocol (better performance)
- **azure-blob-fuse**: Uses BlobFuse (broader compatibility)

### 3. Using Blob Storage in Pods

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: blob-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
  storageClassName: azure-blob-nfs
---
apiVersion: v1
kind: Pod
metadata:
  name: app-with-blob
spec:
  containers:
  - name: app
    image: myapp:latest
    volumeMounts:
    - name: blob-storage
      mountPath: /data
  volumes:
  - name: blob-storage
    persistentVolumeClaim:
      claimName: blob-pvc
```

## Accessing Blob Storage from Applications

### Using Azure SDK

```python
from azure.storage.blob import BlobServiceClient

connection_string = "DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;EndpointSuffix=core.windows.net"
blob_service_client = BlobServiceClient.from_connection_string(connection_string)

# List containers
for container in blob_service_client.list_containers():
    print(container.name)

# Upload a blob
blob_client = blob_service_client.get_blob_client(container="data", blob="file.txt")
with open("file.txt", "rb") as data:
    blob_client.upload_blob(data)
```

### Using Azure CLI

```bash
# Set account key
export AZURE_STORAGE_ACCOUNT="<storage-account-name>"
export AZURE_STORAGE_KEY="<storage-account-key>"

# List containers
az storage container list --output table

# Upload file
az storage blob upload \
  --container-name data \
  --name myfile.txt \
  --file ./myfile.txt
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
| account_tier | Account tier (Standard or Premium) | `string` | `"Standard"` | no |
| replication_type | Replication type | `string` | `"LRS"` | no |
| container_names | List of container names | `list(string)` | `["data", "backups"]` | no |
| enable_versioning | Enable blob versioning | `bool` | `false` | no |
| blob_delete_retention_days | Blob soft delete retention | `number` | `7` | no |
| container_delete_retention_days | Container soft delete retention | `number` | `7` | no |
| allowed_subnet_ids | Subnet IDs allowed access | `list(string)` | `[]` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| storage_account_id | Storage account ID |
| storage_account_name | Storage account name |
| primary_blob_endpoint | Primary blob endpoint |
| primary_access_key | Primary access key (sensitive) |
| primary_connection_string | Primary connection string (sensitive) |
| container_names | Created container names |
| kubernetes_secret_yaml | Secret YAML template (sensitive) |
| kubernetes_storage_class_yaml | StorageClass YAML |
| connection_info | Connection information object |

## Data Protection

- **Soft Delete**: Deleted blobs and containers are retained for 7 days by default
- **Versioning**: Can be enabled to maintain previous versions of blobs
- **Network Isolation**: Private endpoint ensures traffic stays within VNet
- **Encryption**: All data encrypted at rest with Microsoft-managed keys
