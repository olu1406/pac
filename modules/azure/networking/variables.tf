# Variables for Azure Networking Baseline Module

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "Name prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "resource_group_name" {
  description = "Name of the resource group for networking resources"
  type        = string
  default     = "rg-networking"
}

# Virtual Network Configuration
variable "hub_vnet_cidr" {
  description = "CIDR block for the hub VNet"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.hub_vnet_cidr, 0))
    error_message = "Hub VNet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "spoke_vnets" {
  description = "List of spoke VNet configurations"
  type = list(object({
    name          = string
    cidr_block    = string
    allowed_ports = optional(list(number))
  }))
  default = []
  validation {
    condition = alltrue([
      for vnet in var.spoke_vnets : can(cidrhost(vnet.cidr_block, 0))
    ])
    error_message = "All spoke VNet CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

# Connectivity Configuration
variable "enable_hub_spoke_peering" {
  description = "Whether to create VNet peering between hub and spoke VNets"
  type        = bool
  default     = true
}

variable "enable_vpn_gateway" {
  description = "Whether to create VPN Gateway for hybrid connectivity"
  type        = bool
  default     = false
}

variable "vpn_gateway_sku" {
  description = "SKU for the VPN Gateway"
  type        = string
  default     = "VpnGw1"
  validation {
    condition     = contains(["Basic", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5"], var.vpn_gateway_sku)
    error_message = "VPN Gateway SKU must be one of: Basic, VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5."
  }
}

variable "enable_azure_firewall" {
  description = "Whether to deploy Azure Firewall in the hub VNet"
  type        = bool
  default     = false
}

variable "firewall_sku_tier" {
  description = "SKU tier for Azure Firewall"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU tier must be either 'Standard' or 'Premium'."
  }
}

variable "enable_azure_bastion" {
  description = "Whether to deploy Azure Bastion for secure remote access"
  type        = bool
  default     = true
}

# Security Configuration
variable "management_cidrs" {
  description = "List of CIDR blocks allowed for management access (SSH/RDP)"
  type        = list(string)
  default     = []
  validation {
    condition = alltrue([
      for cidr in var.management_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All management CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

# NSG Flow Logs Configuration
variable "enable_nsg_flow_logs" {
  description = "Whether to enable NSG Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain NSG Flow Logs"
  type        = number
  default     = 90
  validation {
    condition     = var.flow_logs_retention_days >= 1 && var.flow_logs_retention_days <= 365
    error_message = "Flow logs retention days must be between 1 and 365."
  }
}

variable "flow_logs_analytics_enabled" {
  description = "Whether to enable Traffic Analytics for NSG Flow Logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Module    = "azure-networking-baseline"
  }
}