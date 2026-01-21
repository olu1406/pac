# Variables for Azure Management Group and Subscription Baseline Module

variable "organization_name" {
  description = "Name of the organization (used for resource naming)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.organization_name))
    error_message = "Organization name must contain only lowercase letters, numbers, and hyphens."
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

# Management Group Configuration
variable "create_management_group_hierarchy" {
  description = "Whether to create management group hierarchy (set to false if hierarchy already exists)"
  type        = bool
  default     = true
}

variable "existing_root_management_group_id" {
  description = "ID of existing root management group (used when create_management_group_hierarchy is false)"
  type        = string
  default     = ""
}

variable "existing_security_management_group_id" {
  description = "ID of existing security management group (used when create_management_group_hierarchy is false)"
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

# Azure Policy Configuration
variable "create_security_policies" {
  description = "Whether to create and assign security baseline policies"
  type        = bool
  default     = true
}

# RBAC Configuration
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
  validation {
    condition = var.security_contact_email == "" || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.security_contact_email))
    error_message = "Security contact email must be a valid email address or empty string."
  }
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
  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Module    = "azure-management-groups-baseline"
  }
}