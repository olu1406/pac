# Outputs for Advanced Azure Landing Zone Example

# Management Groups outputs
output "root_management_group_id" {
  description = "The root management group ID"
  value       = module.management_groups.root_management_group_id
}

output "security_management_group_id" {
  description = "The security management group ID"
  value       = module.management_groups.security_management_group_id
}

output "workloads_management_group_id" {
  description = "The workloads management group ID"
  value       = module.management_groups.workloads_management_group_id
}

output "platform_management_group_id" {
  description = "The platform management group ID"
  value       = module.management_groups.platform_management_group_id
}

output "sandbox_management_group_id" {
  description = "The sandbox management group ID"
  value       = module.management_groups.sandbox_management_group_id
}

output "security_baseline_policy_set_id" {
  description = "ID of the security baseline policy set"
  value       = module.management_groups.security_baseline_policy_set_id
}

output "security_reader_role_id" {
  description = "ID of the custom security reader role"
  value       = module.management_groups.security_reader_role_id
}

output "security_operator_role_id" {
  description = "ID of the custom security operator role"
  value       = module.management_groups.security_operator_role_id
}

output "break_glass_role_id" {
  description = "ID of the break glass emergency access role"
  value       = module.management_groups.break_glass_role_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.management_groups.log_analytics_workspace_id
}

# Networking outputs
output "networking_resource_group_name" {
  description = "Name of the networking resource group"
  value       = module.networking.networking_resource_group_name
}

output "hub_vnet_id" {
  description = "ID of the hub VNet"
  value       = module.networking.hub_vnet_id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet"
  value       = module.networking.hub_vnet_name
}

output "spoke_vnet_ids" {
  description = "IDs of the spoke VNets"
  value       = module.networking.spoke_vnet_ids
}

output "spoke_vnet_names" {
  description = "Names of the spoke VNets"
  value       = module.networking.spoke_vnet_names
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = module.networking.vpn_gateway_id
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = module.networking.vpn_gateway_public_ip
}

output "azure_firewall_id" {
  description = "ID of the Azure Firewall"
  value       = module.networking.azure_firewall_id
}

output "azure_firewall_private_ip" {
  description = "Private IP address of the Azure Firewall"
  value       = module.networking.azure_firewall_private_ip
}

output "azure_firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = module.networking.azure_firewall_public_ip
}

output "azure_bastion_id" {
  description = "ID of the Azure Bastion Host"
  value       = module.networking.azure_bastion_id
}

output "azure_bastion_fqdn" {
  description = "FQDN of the Azure Bastion Host"
  value       = module.networking.azure_bastion_fqdn
}

output "flow_logs_storage_account_name" {
  description = "Name of the storage account for NSG Flow Logs"
  value       = module.networking.flow_logs_storage_account_name
}

output "flow_logs_workspace_id" {
  description = "ID of the Log Analytics workspace for Traffic Analytics"
  value       = module.networking.flow_logs_workspace_id
}

# Security resources outputs
output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "security_logs_storage_account_name" {
  description = "Name of the security logs storage account"
  value       = azurerm_storage_account.security_logs.name
}

output "security_resource_group_name" {
  description = "Name of the security resource group"
  value       = azurerm_resource_group.security.name
}