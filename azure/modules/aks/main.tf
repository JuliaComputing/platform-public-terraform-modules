resource "azurerm_kubernetes_cluster" "main" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name               = "system"
    vm_size            = var.node_vm_size
    vnet_subnet_id     = var.subnet_id
    auto_scaling_enabled = true
    min_count          = var.min_node_count
    max_count          = var.max_node_count
    node_count         = var.initial_node_count
    os_disk_size_gb    = var.os_disk_size_gb
    type               = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    load_balancer_sku   = "standard"
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  storage_profile {
    blob_driver_enabled         = true
    disk_driver_enabled         = true
    file_driver_enabled         = true
    snapshot_controller_enabled = true
  }

  web_app_routing {
    dns_zone_ids = []
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "additional" {
  for_each = var.additional_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = each.value.vm_size
  vnet_subnet_id        = var.subnet_id
  auto_scaling_enabled  = true
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  node_count            = each.value.initial_node_count
  os_disk_size_gb       = each.value.os_disk_size_gb
  node_labels           = each.value.node_labels
  node_taints           = each.value.node_taints
  mode                  = each.value.mode

  upgrade_settings {
    max_surge = "10%"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      node_count
    ]
  }
}

# Role assignment for AKS to manage network resources
resource "azurerm_role_assignment" "aks_network" {
  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.identity[0].principal_id
}
