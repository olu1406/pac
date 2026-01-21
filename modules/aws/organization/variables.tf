# Variables for AWS Organization and Account Baseline Module

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

variable "create_organization" {
  description = "Whether to create AWS Organizations (set to false if organization already exists)"
  type        = bool
  default     = true
}

variable "security_account_id" {
  description = "AWS account ID for the security account (for cross-account access)"
  type        = string
  default     = ""
  validation {
    condition = var.security_account_id == "" || can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "Security account ID must be a 12-digit AWS account ID or empty string."
  }
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_break_glass_role" {
  description = "Whether to create a break glass emergency access role"
  type        = bool
  default     = false
}

variable "break_glass_users" {
  description = "List of IAM user ARNs allowed to assume the break glass role"
  type        = list(string)
  default     = []
}

variable "enable_guardduty_s3_export" {
  description = "Whether to enable GuardDuty findings export to S3"
  type        = bool
  default     = false
}

variable "threat_intel_sets" {
  description = "List of threat intelligence sets for GuardDuty"
  type = list(object({
    name     = string
    format   = string
    location = string
  }))
  default = []
}

variable "trusted_ip_sets" {
  description = "List of trusted IP sets for GuardDuty"
  type = list(object({
    name     = string
    format   = string
    location = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Module    = "aws-organization-baseline"
  }
}