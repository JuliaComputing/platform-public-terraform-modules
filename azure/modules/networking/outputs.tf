output "vnet_id" {
  description = "ID of the Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "postgresql_subnet_id" {
  description = "ID of the PostgreSQL subnet"
  value       = azurerm_subnet.postgresql.id
}

output "private_endpoints_subnet_id" {
  description = "ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "aks_nsg_id" {
  description = "ID of the AKS Network Security Group"
  value       = azurerm_network_security_group.aks.id
}

output "postgresql_nsg_id" {
  description = "ID of the PostgreSQL Network Security Group"
  value       = azurerm_network_security_group.postgresql.id
}

output "private_endpoints_nsg_id" {
  description = "ID of the private endpoints Network Security Group"
  value       = azurerm_network_security_group.private_endpoints.id
}

output "postgres_private_dns_zone_id" {
  description = "ID of the PostgreSQL private DNS zone"
  value       = azurerm_private_dns_zone.postgres.id
}

output "blob_private_dns_zone_id" {
  description = "ID of the Blob Storage private DNS zone"
  value       = azurerm_private_dns_zone.blob.id
}

output "file_private_dns_zone_id" {
  description = "ID of the File Storage private DNS zone"
  value       = azurerm_private_dns_zone.file.id
}
