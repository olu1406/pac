# Outputs for Azure Networking Baseline Module

# Resource Group outputs
output "networking_resource_group_name" {
  description = "Name of the networking resource group"
  value       = azurerm_resource_group.networking.name
}

output "networking_resource_group_id" {
  description = "ID of the networking resource group"
  value       = azurerm_resource_group.networking.id
}

# Hub VNet outputs
output "hub_vnet_id" {
  description = "ID of the hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet"
  value       = azurerm_virtual_network.hub.name
}

output "hub_vnet_cidr" {
  description = "CIDR block of the hub VNet"
  value       = azurerm_virtual_network.hub.address_space[0]
}

output "hub_gateway_subnet_id" {
  description = "ID of the hub VNet gateway subnet"
  value       = azurerm_subnet.hub_gateway.id
}

output "hub_firewall_subnet_id" {
  description = "ID of the hub VNet firewall subnet"
  value       = azurerm_subnet.hub_firewall.id
}

output "hub_bastion_subnet_id" {
  description = "ID of the hub VNet bastion subnet"
  value       = azurerm_subnet.hub_bastion.id
}

output "hub_management_subnet_id" {
  description = "ID of the hub VNet management subnet"
  value       = azurerm_subnet.hub_management.id
}

# Spoke VNet outputs
output "spoke_vnet_ids" {
  description = "IDs of the spoke VNets"
  value       = azurerm_virtual_network.spoke[*].id
}

output "spoke_vnet_names" {
  description = "Names of the spoke VNets"
  value       = azurerm_virtual_network.spoke[*].name
}

output "spoke_vnet_cidrs" {
  description = "CIDR blocks of the spoke VNets"
  value       = [for vnet in azurerm_virtual_network.spoke : vnet.address_space[0]]
}

output "spoke_app_subnet_ids" {
  description = "IDs of the spoke VNet application subnets"
  value = {
    for i, vnet in var.spoke_vnets : vnet.name => azurerm_subnet.spoke_app[i].id
  }
}

output "spoke_data_subnet_ids" {
  description = "IDs of the spoke VNet data subnets"
  value = {
    for i, vnet in var.spoke_vnets : vnet.name => azurerm_subnet.spoke_data[i].id
  }
}

# VNet Peering outputs
output "hub_to_spoke_peering_ids" {
  description = "IDs of the hub-to-spoke VNet peerings"
  value = var.enable_hub_spoke_peering ? {
    for i, vnet in var.spoke_vnets : vnet.name => azurerm_virtual_network_peering.hub_to_spoke[i].id
  } : {}
}

output "spoke_to_hub_peering_ids" {
  description = "IDs of the spoke-to-hub VNet peerings"
  value = var.enable_hub_spoke_peering ? {
    for i, vnet in var.spoke_vnets : vnet.name => azurerm_virtual_network_peering.spoke_to_hub[i].id
  } : {}
}

# Gateway outputs
output "vpn_gateway_id" {
  description = "ID of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_virtual_network_gateway.vpn[0].id : null
}

output "vpn_gateway_public_ip" {
  description = "Public IP address of the VPN Gateway"
  value       = var.enable_vpn_gateway ? azurerm_public_ip.vpn_gateway[0].ip_address : null
}

# Azure Firewall outputs
output "azure_firewall_id" {
  description = "ID of the Azure Firewall"
  value       = var.enable_azure_firewall ? azurerm_firewall.main[0].id : null
}

output "azure_firewall_private_ip" {
  description = "Private IP address of the Azure Firewall"
  value       = var.enable_azure_firewall ? azurerm_firewall.main[0].ip_configuration[0].private_ip_address : null
}

output "azure_firewall_public_ip" {
  description = "Public IP address of the Azure Firewall"
  value       = var.enable_azure_firewall ? azurerm_public_ip.firewall[0].ip_address : null
}

output "firewall_policy_id" {
  description = "ID of the Azure Firewall Policy"
  value       = var.enable_azure_firewall ? azurerm_firewall_policy.main[0].id : null
}

# Azure Bastion outputs
output "azure_bastion_id" {
  description = "ID of the Azure Bastion Host"
  value       = var.enable_azure_bastion ? azurerm_bastion_host.main[0].id : null
}

output "azure_bastion_fqdn" {
  description = "FQDN of the Azure Bastion Host"
  value       = var.enable_azure_bastion ? azurerm_bastion_host.main[0].dns_name : null
}

# NSG outputs
output "hub_management_nsg_id" {
  description = "ID of the hub management NSG"
  value       = azurerm_network_security_group.hub_management.id
}

output "spoke_app_nsg_ids" {
  description = "IDs of the spoke application NSGs"
  value = {
    for i, vnet in var.spoke_vnets : vnet.name => azurerm_network_security_group.spoke_app[i].id
  }
}

output "spoke_data_nsg_ids" {
  description = "IDs of the spoke data NSGs"
  value = {
    for i, vnet in var.spoke_vnets : vnet.name => azurerm_network_security_group.spoke_data[i].id
  }
}

# Flow Logs outputs
output "flow_logs_storage_account_id" {
  description = "ID of the storage account for NSG Flow Logs"
  value       = var.enable_nsg_flow_logs ? azurerm_storage_account.flow_logs[0].id : null
}

output "flow_logs_storage_account_name" {
  description = "Name of the storage account for NSG Flow Logs"
  value       = var.enable_nsg_flow_logs ? azurerm_storage_account.flow_logs[0].name : null
}

output "flow_logs_workspace_id" {
  description = "ID of the Log Analytics workspace for Traffic Analytics"
  value       = var.enable_nsg_flow_logs && var.flow_logs_analytics_enabled ? azurerm_log_analytics_workspace.flow_logs[0].id : null
}

output "network_watcher_id" {
  description = "ID of the Network Watcher"
  value       = var.enable_nsg_flow_logs ? azurerm_network_watcher.main[0].id : null
}