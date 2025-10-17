output "server_id" {
  description = "ID of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.id
}

output "server_name" {
  description = "Name of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.name
}

output "server_fqdn" {
  description = "FQDN of the PostgreSQL Flexible Server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "database_name" {
  description = "Name of the database"
  value       = azurerm_postgresql_flexible_server_database.main.name
}

output "administrator_login" {
  description = "Administrator login for the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
  sensitive   = true
}

output "connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}@${azurerm_postgresql_flexible_server.main.name}:PASSWORD@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}?sslmode=require"
  sensitive   = true
}

output "kubernetes_secret_yaml" {
  description = "Kubernetes Secret YAML for PostgreSQL connection"
  value = <<-EOT
    apiVersion: v1
    kind: Secret
    metadata:
      name: postgresql-connection
      namespace: default
    type: Opaque
    stringData:
      host: ${azurerm_postgresql_flexible_server.main.fqdn}
      port: "5432"
      database: ${azurerm_postgresql_flexible_server_database.main.name}
      username: ${azurerm_postgresql_flexible_server.main.administrator_login}
      # Password should be set separately using kubectl or a secrets management solution
      # password: <SET_THIS_VALUE>
      connection-string: "postgresql://${azurerm_postgresql_flexible_server.main.administrator_login}@${azurerm_postgresql_flexible_server.main.name}:PASSWORD@${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}?sslmode=require"
  EOT
  sensitive = true
}
