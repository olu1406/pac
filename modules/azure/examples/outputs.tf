# Outputs for Azure Landing Zone Examples

# Management Groups Outputs
output "root_management_group_id" {
  description = "ID of the root management group"
  value       = module.management_groups.root_management_group_id
}

output "security_management_group_id" {
  description = "ID of the security management group"
  value       = module.management_groups.security_management_group_id
}

output "workloads_management_group_id" {
  description = "ID of the workloads management group"
  value       = module.management_groups.workloads_management_group_id
}

output "platform_management_group_id" {
  description = "ID of the platform management group"
  value       = module.management_groups.platform_management_group_id
}

output "sandbox_management_group_id" {
  description = "ID of the sandbox management group"
  value       = module.management_groups.sandbox_management_group_id
}

# Security Outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.management_groups.log_analytics_workspace_id
}

output "security_resource_group_name" {
  description = "Name of the security resource group"
  value       = module.management_groups.security_resource_group_name
}

# Networking Outputs
output "hub_vnet_id" {
  description = "ID of the hub VNet"
  value       = module.networking.hub_vnet_id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet"
  value       = module.networking.hub_vnet_name
}

output "spoke_vnet_ids" {
  description = "Map of spoke VNet names to IDs"
  value       = module.networking.spoke_vnet_ids
}

output "spoke_vnet_names" {
  description = "List of spoke VNet names"
  value       = module.networking.spoke_vnet_names
}

# Security Infrastructure Outputs
output "azure_bastion_id" {
  description = "ID of the Azure Bastion host"
  value       = module.networking.azure_bastion_id
}

output "azure_firewall_id" {
  description = "ID of the Azure Firewall"
  value       = module.networking.azure_firewall_id
}

output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = module.networking.vpn_gateway_id
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = module.networking.vpn_gateway_public_ip
}

# Flow Logs Outputs
output "flow_logs_storage_account_id" {
  description = "ID of the storage account for NSG Flow Logs"
  value       = module.networking.flow_logs_storage_account_id
}

# Network Security Groups
output "hub_nsg_ids" {
  description = "Map of hub NSG names to IDs"
  value       = module.networking.hub_nsg_ids
}

output "spoke_nsg_ids" {
  description = "Map of spoke NSG names to IDs"
  value       = module.networking.spoke_nsg_ids
}

# Environment Information
output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "location" {
  description = "Azure region"
  value       = var.location
}

output "organization_name" {
  description = "Organization name"
  value       = var.organization_name
}

# Resource Group Information
output "networking_resource_group_name" {
  description = "Name of the networking resource group"
  value       = module.networking.resource_group_name
}

output "networking_resource_group_id" {
  description = "ID of the networking resource group"
  value       = module.networking.resource_group_id
}