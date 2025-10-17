output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

output "primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "Primary connection string for the storage account"
  value       = azurerm_storage_account.main.primary_connection_string
  sensitive   = true
}

output "container_names" {
  description = "Names of the created blob containers"
  value       = [for container in azurerm_storage_container.containers : container.name]
}

output "private_endpoint_id" {
  description = "ID of the private endpoint"
  value       = azurerm_private_endpoint.blob.id
}

output "kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for Azure Blob Storage credentials"
  value = <<-EOT
    apiVersion: v1
    kind: Secret
    metadata:
      name: azure-blob-secret
      namespace: default
    type: Opaque
    stringData:
      azurestorageaccountname: ${azurerm_storage_account.main.name}
      # azurestorageaccountkey should be set separately using kubectl or a secrets management solution
      # azurestorageaccountkey: <SET_THIS_VALUE>
      # Connection string for applications that need it
      # connection-string: <SET_THIS_VALUE>
  EOT
  sensitive = true
}

output "kubernetes_storage_class_yaml" {
  description = "Kubernetes StorageClass YAML for Azure Blob Storage using CSI driver"
  value = <<-EOT
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azure-blob-nfs
    provisioner: blob.csi.azure.com
    parameters:
      protocol: nfs
      storageAccount: ${azurerm_storage_account.main.name}
      resourceGroup: ${var.resource_group_name}
    allowVolumeExpansion: true
    volumeBindingMode: Immediate
    reclaimPolicy: Delete
    ---
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azure-blob-fuse
    provisioner: blob.csi.azure.com
    parameters:
      protocol: fuse
      storageAccount: ${azurerm_storage_account.main.name}
      resourceGroup: ${var.resource_group_name}
    allowVolumeExpansion: true
    volumeBindingMode: Immediate
    reclaimPolicy: Delete
  EOT
}

output "connection_info" {
  description = "Connection information for blob storage"
  value = {
    storage_account_name = azurerm_storage_account.main.name
    blob_endpoint        = azurerm_storage_account.main.primary_blob_endpoint
    containers           = [for container in azurerm_storage_container.containers : container.name]
  }
}
