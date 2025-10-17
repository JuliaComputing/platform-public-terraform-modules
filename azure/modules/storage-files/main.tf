resource "azurerm_storage_account" "main" {
  name                     = var.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Premium"
  account_replication_type = var.replication_type
  account_kind             = "FileStorage"

  public_network_access_enabled   = false
  allow_nested_items_to_be_public = false

  min_tls_version = "TLS1_2"

  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags
}

resource "azurerm_storage_share" "shares" {
  for_each           = toset(var.file_share_names)
  name               = each.value
  storage_account_id = azurerm_storage_account.main.id
  quota              = var.file_share_quota_gb
  enabled_protocol   = "SMB"
  access_tier        = "Premium"
}

resource "azurerm_private_endpoint" "files" {
  name                = "${var.storage_account_name}-files-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.storage_account_name}-files-psc"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["file"]
  }

  private_dns_zone_group {
    name                 = "files-dns-zone-group"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}
