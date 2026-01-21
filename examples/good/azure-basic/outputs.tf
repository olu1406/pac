output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "virtual_network_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "subnet_ids" {
  description = "IDs of the subnets"
  value = {
    web  = azurerm_subnet.web.id
    app  = azurerm_subnet.app.id
    data = azurerm_subnet.data.id
  }
}

output "network_security_group_ids" {
  description = "IDs of the network security groups"
  value = {
    web  = azurerm_network_security_group.web.id
    app  = azurerm_network_security_group.app.id
    data = azurerm_network_security_group.data.id
  }
}

output "storage_account_name" {
  description = "Name of the secure storage account"
  value       = azurerm_storage_account.secure.name
}

output "storage_account_id" {
  description = "ID of the secure storage account"
  value       = azurerm_storage_account.secure.id
}

output "storage_container_name" {
  description = "Name of the secure storage container"
  value       = azurerm_storage_container.secure.name
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "service_principal_application_id" {
  description = "Application ID of the service principal"
  value       = azuread_service_principal.main.client_id
}

output "service_principal_object_id" {
  description = "Object ID of the service principal"
  value       = azuread_service_principal.main.object_id
}

output "custom_role_definition_id" {
  description = "ID of the custom RBAC role definition"
  value       = azurerm_role_definition.storage_reader.role_definition_resource_id
}

output "public_ip_address" {
  description = "Public IP address for testing"
  value       = azurerm_public_ip.test.ip_address
}

output "flow_log_id" {
  description = "ID of the NSG Flow Log"
  value       = var.enable_flow_logs ? azurerm_network_watcher_flow_log.web[0].id : null
}