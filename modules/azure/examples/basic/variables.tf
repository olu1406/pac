# Variables for Basic Azure Landing Zone Example

variable "organization_name" {
  description = "Name of the organization"
  type        = string
  default     = "mycompany"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

# Management Groups variables
variable "create_management_group_hierarchy" {
  description = "Whether to create management group hierarchy"
  type        = bool
  default     = true
}

variable "security_subscription_ids" {
  description = "List of subscription IDs for security management group"
  type        = list(string)
  default     = []
}

variable "workload_subscription_ids" {
  description = "List of subscription IDs for workloads management group"
  type        = list(string)
  default     = []
}

variable "enable_defender_for_cloud" {
  description = "Whether to enable Microsoft Defender for Cloud"
  type        = bool
  default     = true
}

variable "security_contact_email" {
  description = "Email address for security contact notifications"
  type        = string
  default     = ""
}

variable "create_log_analytics_workspace" {
  description = "Whether to create a Log Analytics workspace"
  type        = bool
  default     = true
}

variable "security_reader_groups" {
  description = "List of Azure AD group object IDs for security reader role"
  type        = list(string)
  default     = []
}

# Networking variables
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "mycompany"
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
  default = [
    {
      name          = "app"
      cidr_block    = "10.1.0.0/16"
      allowed_ports = [80, 443]
    }
  ]
}

variable "management_cidrs" {
  description = "List of CIDR blocks allowed for management access"
  type        = list(string)
  default     = []
}

variable "enable_hub_spoke_peering" {
  description = "Whether to create VNet peering between hub and spoke VNets"
  type        = bool
  default     = true
}

variable "enable_azure_bastion" {
  description = "Whether to deploy Azure Bastion"
  type        = bool
  default     = true
}

variable "enable_nsg_flow_logs" {
  description = "Whether to enable NSG Flow Logs"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Example   = "basic-azure-landing-zone"
  }
}