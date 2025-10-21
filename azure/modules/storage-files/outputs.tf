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
      protocol: smb
    allowVolumeExpansion: true
    volumeBindingMode: Immediate
    reclaimPolicy: Retain
    mountOptions:
      - dir_mode=0777
      - file_mode=0777
      - uid=1000
      - gid=1000
      - mfsymlink
      - cache=strict
      - nosharesock
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
  description = "Kubernetes PersistentVolume YAML for juliahub-config file share"
  value       = <<-EOT
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
      storageClassName: azurefile-csi-premium-jh
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
        - uid=1000
        - gid=1000
        - mfsymlinks
        - cache=strict # https://linux.die.net/man/8/mount.cifs
        - nosharesock # reduce probability of reconnect race
        - actimeo=30 # reduce latency for metadata-heavy workload
        - nobrl # disable sending byte range lock requests to the server and for applications which have challenges with posix locks
    ---
  EOT
}
