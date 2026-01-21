# Outputs for Basic Azure Landing Zone Example

# Management Groups outputs
output "root_management_group_id" {
  description = "The root management group ID"
  value       = module.management_groups.root_management_group_id
}

output "security_management_group_id" {
  description = "The security management group ID"
  value       = module.management_groups.security_management_group_id
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.management_groups.log_analytics_workspace_id
}

# Networking outputs
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

output "azure_bastion_id" {
  description = "ID of the Azure Bastion Host"
  value       = module.networking.azure_bastion_id
}

output "flow_logs_storage_account_name" {
  description = "Name of the storage account for NSG Flow Logs"
  value       = module.networking.flow_logs_storage_account_name
}