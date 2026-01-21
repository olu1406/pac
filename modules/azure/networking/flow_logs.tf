# NSG Flow Logs Configuration

# Storage account for NSG Flow Logs
resource "azurerm_storage_account" "flow_logs" {
  count = var.enable_nsg_flow_logs ? 1 : 0

  name                     = "${replace(var.name_prefix, "-", "")}flowlogs${random_string.storage_suffix[0].result}"
  resource_group_name      = azurerm_resource_group.networking.name
  location                 = azurerm_resource_group.networking.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Security configurations
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled       = true

  # Network access rules
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    # Allow access from management CIDRs
    ip_rules = var.management_cidrs
    
    # Allow access from VNets
    virtual_network_subnet_ids = concat(
      [azurerm_subnet.hub_management.id],
      azurerm_subnet.spoke_app[*].id
    )
  }

  tags = var.tags
}

# Random string for storage account name uniqueness
resource "random_string" "storage_suffix" {
  count = var.enable_nsg_flow_logs ? 1 : 0

  length  = 8
  special = false
  upper   = false
}

# Log Analytics Workspace for NSG Flow Logs
resource "azurerm_log_analytics_workspace" "flow_logs" {
  count = var.enable_nsg_flow_logs && var.flow_logs_analytics_enabled ? 1 : 0

  name                = "${var.name_prefix}-flow-logs-workspace"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku                 = "PerGB2018"
  retention_in_days   = var.flow_logs_retention_days

  tags = var.tags
}

# Network Watcher (required for Flow Logs)
resource "azurerm_network_watcher" "main" {
  count = var.enable_nsg_flow_logs ? 1 : 0

  name                = "${var.name_prefix}-network-watcher"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  tags = var.tags
}

# NSG Flow Logs for Hub Management NSG
resource "azurerm_network_watcher_flow_log" "hub_management" {
  count = var.enable_nsg_flow_logs ? 1 : 0

  network_watcher_name = azurerm_network_watcher.main[0].name
  resource_group_name  = azurerm_resource_group.networking.name
  name                 = "${var.name_prefix}-hub-management-flow-log"

  network_security_group_id = azurerm_network_security_group.hub_management.id
  storage_account_id        = azurerm_storage_account.flow_logs[0].id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = var.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = var.flow_logs_analytics_enabled
    workspace_id          = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].workspace_id : null
    workspace_region      = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].location : null
    workspace_resource_id = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].id : null
    interval_in_minutes   = 10
  }

  tags = var.tags
}

# NSG Flow Logs for Spoke Application NSGs
resource "azurerm_network_watcher_flow_log" "spoke_app" {
  count = var.enable_nsg_flow_logs ? length(var.spoke_vnets) : 0

  network_watcher_name = azurerm_network_watcher.main[0].name
  resource_group_name  = azurerm_resource_group.networking.name
  name                 = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-app-flow-log"

  network_security_group_id = azurerm_network_security_group.spoke_app[count.index].id
  storage_account_id        = azurerm_storage_account.flow_logs[0].id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = var.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = var.flow_logs_analytics_enabled
    workspace_id          = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].workspace_id : null
    workspace_region      = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].location : null
    workspace_resource_id = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].id : null
    interval_in_minutes   = 10
  }

  tags = merge(var.tags, {
    Spoke = var.spoke_vnets[count.index].name
  })
}

# NSG Flow Logs for Spoke Data NSGs
resource "azurerm_network_watcher_flow_log" "spoke_data" {
  count = var.enable_nsg_flow_logs ? length(var.spoke_vnets) : 0

  network_watcher_name = azurerm_network_watcher.main[0].name
  resource_group_name  = azurerm_resource_group.networking.name
  name                 = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-data-flow-log"

  network_security_group_id = azurerm_network_security_group.spoke_data[count.index].id
  storage_account_id        = azurerm_storage_account.flow_logs[0].id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = var.flow_logs_retention_days
  }

  traffic_analytics {
    enabled               = var.flow_logs_analytics_enabled
    workspace_id          = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].workspace_id : null
    workspace_region      = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].location : null
    workspace_resource_id = var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].id : null
    interval_in_minutes   = 10
  }

  tags = merge(var.tags, {
    Spoke = var.spoke_vnets[count.index].name
  })
}