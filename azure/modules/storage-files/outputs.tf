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

output "kubernetes_storage_class_yaml" {
  description = "Kubernetes StorageClass YAML for Azure Files"
  value = <<-EOT
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azure-file-premium
    provisioner: file.csi.azure.com
    parameters:
      skuName: Premium_LRS
      storageAccount: ${azurerm_storage_account.main.name}
      resourceGroup: ${var.resource_group_name}
      protocol: smb
    allowVolumeExpansion: true
    volumeBindingMode: Immediate
    reclaimPolicy: Retain
    mountOptions:
      - dir_mode=0777
      - file_mode=0777
      - uid=0
      - gid=0
      - mfsymlinks
      - cache=strict
      - nosharesock
  EOT
}

output "kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for Azure Files credentials"
  value = <<-EOT
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
  sensitive = true
}

output "kubernetes_pv_yaml" {
  description = "Kubernetes PersistentVolume YAML for juliahub-config file share"
  value = <<-EOT
    apiVersion: v1
    kind: PersistentVolume
    metadata:
      name: juliahub-config-pv
    spec:
      capacity:
        storage: ${var.file_share_quota_gb}Gi
      accessModes:
        - ReadWriteMany
      persistentVolumeReclaimPolicy: Retain
      storageClassName: azure-file-premium
      csi:
        driver: file.csi.azure.com
        volumeHandle: juliahub-config-pv
        volumeAttributes:
          resourceGroup: ${var.resource_group_name}
          storageAccount: ${azurerm_storage_account.main.name}
          shareName: juliahub-config
          protocol: smb
        nodeStageSecretRef:
          name: azure-files-secret
          namespace: default
      mountOptions:
        - dir_mode=0777
        - file_mode=0777
        - uid=0
        - gid=0
        - mfsymlinks
        - cache=strict
        - nosharesock
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: juliahub-config-pvc
      namespace: default
    spec:
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: ${var.file_share_quota_gb}Gi
      storageClassName: azure-file-premium
      volumeName: juliahub-config-pv
  EOT
}
