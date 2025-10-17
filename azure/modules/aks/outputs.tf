output "cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.fqdn
}

output "kube_config" {
  description = "Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "kubelet_identity" {
  description = "Kubelet identity object"
  value       = azurerm_kubernetes_cluster.main.kubelet_identity
}

output "cluster_identity_principal_id" {
  description = "Principal ID of the cluster identity"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL"
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "storage_classes_yaml" {
  description = "YAML configurations for storage classes"
  value       = <<-EOT
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azure-disk-premium
    provisioner: disk.csi.azure.com
    parameters:
      skuName: Premium_LRS
      kind: Managed
    allowVolumeExpansion: true
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: Delete
    ---
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azure-disk-standard
    provisioner: disk.csi.azure.com
    parameters:
      skuName: StandardSSD_LRS
      kind: Managed
    allowVolumeExpansion: true
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: Delete
    ---
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: azure-blob
    provisioner: blob.csi.azure.com
    parameters:
      skuName: Standard_LRS
    allowVolumeExpansion: true
    volumeBindingMode: Immediate
    reclaimPolicy: Delete
  EOT
}
