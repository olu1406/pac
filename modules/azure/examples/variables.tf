# Variables for Azure Landing Zone Examples
# These variables are used by all example configurations and can be set via environment files

# Organization Configuration
variable "organization_name" {
  description = "Name of the organization (used for resource naming)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

# Management Group Configuration
variable "create_management_group_hierarchy" {
  description = "Whether to create management group hierarchy"
  type        = bool
  default     = true
}

variable "existing_root_management_group_id" {
  description = "ID of existing root management group"
  type        = string
  default     = ""
}

variable "existing_security_management_group_id" {
  description = "ID of existing security management group"
  type        = string
  default     = ""
}

variable "root_subscription_ids" {
  description = "List of subscription IDs to assign to root management group"
  type        = list(string)
  default     = []
}

variable "security_subscription_ids" {
  description = "List of subscription IDs to assign to security management group"
  type        = list(string)
  default     = []
}

variable "workload_subscription_ids" {
  description = "List of subscription IDs to assign to workloads management group"
  type        = list(string)
  default     = []
}

variable "platform_subscription_ids" {
  description = "List of subscription IDs to assign to platform management group"
  type        = list(string)
  default     = []
}

variable "sandbox_subscription_ids" {
  description = "List of subscription IDs to assign to sandbox management group"
  type        = list(string)
  default     = []
}

# Security Configuration
variable "create_security_policies" {
  description = "Whether to create and assign security baseline policies"
  type        = bool
  default     = true
}

variable "create_custom_roles" {
  description = "Whether to create custom RBAC roles"
  type        = bool
  default     = true
}

variable "security_reader_groups" {
  description = "List of Azure AD group object IDs for security reader role"
  type        = list(string)
  default     = []
}

variable "security_operator_groups" {
  description = "List of Azure AD group object IDs for security operator role"
  type        = list(string)
  default     = []
}

variable "enable_break_glass_role" {
  description = "Whether to create a break glass emergency access role"
  type        = bool
  default     = false
}

variable "break_glass_user_ids" {
  description = "List of Azure AD user object IDs for break glass role"
  type        = list(string)
  default     = []
}

# Microsoft Defender for Cloud Configuration
variable "enable_defender_for_cloud" {
  description = "Whether to enable Microsoft Defender for Cloud"
  type        = bool
  default     = true
}

variable "defender_subscription_ids" {
  description = "List of subscription IDs to enable Defender for Cloud on"
  type        = list(string)
  default     = []
}

variable "security_contact_email" {
  description = "Email address for security contact notifications"
  type        = string
  default     = ""
}

variable "security_contact_phone" {
  description = "Phone number for security contact notifications"
  type        = string
  default     = ""
}

variable "create_log_analytics_workspace" {
  description = "Whether to create a Log Analytics workspace for security logging"
  type        = bool
  default     = true
}

variable "security_resource_group_name" {
  description = "Name of the resource group for security resources"
  type        = string
  default     = "rg-security"
}

variable "log_retention_days" {
  description = "Number of days to retain logs in Log Analytics workspace"
  type        = number
  default     = 90
}

# Networking Configuration
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for networking resources"
  type        = string
  default     = "rg-networking"
}

variable "hub_vnet_cidr" {
  description = "CIDR block for the hub VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_vnets" {
  description = "List of spoke VNet configurations"
  type = list(object({
    name          = string
    cidr_block    = string
    allowed_ports = optional(list(number))
  }))
  default = []
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
}

variable "enable_azure_bastion" {
  description = "Whether to deploy Azure Bastion for secure remote access"
  type        = bool
  default     = true
}

# Security Configuration
variable "management_cidrs" {
  description = "List of CIDR blocks allowed for management access"
  type        = list(string)
  default     = []
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
}

variable "flow_logs_analytics_enabled" {
  description = "Whether to enable Traffic Analytics for NSG Flow Logs"
  type        = bool
  default     = true
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
  }
}