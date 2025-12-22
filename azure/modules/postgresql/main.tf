locals {
  required_extensions = ["uuid-ossp", "pg_trgm", "pgcrypto"]
  all_extensions      = concat(local.required_extensions, var.postgresql_additional_extensions)
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                = var.server_name
  location            = var.location
  resource_group_name = var.resource_group_name

  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password

  sku_name     = var.sku_name
  version      = var.postgresql_version
  storage_mb   = var.storage_mb
  storage_tier = var.storage_tier

  delegated_subnet_id = var.subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  public_network_access_enabled = false

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup_enabled

  zone = var.zone

  tags = var.tags

  depends_on = [var.private_dns_zone_id]
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = join(",", local.all_extensions)
}
