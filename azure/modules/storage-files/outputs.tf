output "storage_account_id" {
  description = "ID of the storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Name of the storage account"
  value       = azurerm_storage_account.main.name
}

output "primary_file_endpoint" {
  description = "Primary file endpoint"
  value       = azurerm_storage_account.main.primary_file_endpoint
}

output "primary_access_key" {
  description = "Primary access key for the storage account"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "file_share_names" {
  description = "Names of the created file shares"
  value       = [for share in azurerm_storage_share.shares : share.name]
}

output "file_share_urls" {
  description = "URLs of the created file shares"
  value       = [for share in azurerm_storage_share.shares : share.url]
}

output "private_endpoint_id" {
  description = "ID of the private endpoint"
  value       = azurerm_private_endpoint.files.id
}

output "private_endpoint_ip" {
  description = "Private IP address of the file storage endpoint"
  value       = azurerm_private_endpoint.files.private_service_connection[0].private_ip_address
}

output "kubernetes_storage_class_yaml" {
  description = "Kubernetes StorageClass YAML for Azure Files"
  value       = <<-EOT
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azurefile-csi-premium-jh
    provisioner: file.csi.azure.com
    parameters:
      skuName: Premium_LRS
      storageAccount: ${azurerm_storage_account.main.name}
      resourceGroup: ${var.resource_group_name}
      protocol: nfs
      networkEndpointType: privateEndpoint
      encryptInTransit: "true"
    allowVolumeExpansion: true
    volumeBindingMode: Immediate
    reclaimPolicy: Retain
    mountOptions:
      - nconnect=4
      - noresvport
      - actimeo=30
      - rsize=1048576
      - wsize=1048576
  EOT
}

output "kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for Azure Files credentials"
  value       = <<-EOT
    apiVersion: v1
    kind: Secret
    metadata:
      name: azure-files-secret
      namespace: default
    type: Opaque
    stringData:
      azurestorageaccountname: ${azurerm_storage_account.main.name}
      # azurestorageaccountkey should be set separately using kubectl or a secrets management solution
      # azurestorageaccountkey: <SET_THIS_VALUE>
  EOT
  sensitive   = true
}

output "kubernetes_pv_yaml" {
  description = "Kubernetes PersistentVolume YAML for all file shares"
  value = join("\n", [for share_name in var.file_share_names : <<-EOT
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: ${share_name}-pv
    spec:
      capacity:
        storage: ${var.file_share_quota_gb}Gi
      accessModes:
        - ReadWriteMany
      persistentVolumeReclaimPolicy: Retain
      storageClassName: azurefile-csi-premium-jh
      csi:
        driver: file.csi.azure.com
        volumeHandle: ${share_name}-pv
        volumeAttributes:
          resourceGroup: ${var.resource_group_name}
          storageAccount: ${azurerm_storage_account.main.name}
          shareName: ${share_name}
          protocol: nfs
          server: ${azurerm_storage_account.main.name}.privatelink.file.core.windows.net
          encryptInTransit: "true"
      mountOptions:
        - nconnect=4
        - noresvport
        - actimeo=30
        - rsize=1048576
        - wsize=1048576
    ---
  EOT
  ])
}
