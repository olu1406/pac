variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "secure-example"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US"

  validation {
    condition     = length(var.location) > 0
    error_message = "Location must not be empty."
  }
}

variable "vnet_cidr" {
  description = "CIDR block for Virtual Network"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_cidr, 0))
    error_message = "VNet CIDR must be a valid IPv4 CIDR block."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR block allowed for SSH access (replace with your IP range)"
  type        = string
  default     = "203.0.113.0/24"  # RFC 5737 documentation range

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "Allowed SSH CIDR must be a valid IPv4 CIDR block."
  }
}

variable "allowed_rdp_cidr" {
  description = "CIDR block allowed for RDP access (replace with your IP range)"
  type        = string
  default     = "203.0.113.0/24"  # RFC 5737 documentation range

  validation {
    condition     = can(cidrhost(var.allowed_rdp_cidr, 0))
    error_message = "Allowed RDP CIDR must be a valid IPv4 CIDR block."
  }
}

variable "storage_account_prefix" {
  description = "Prefix for storage account names (must be globally unique)"
  type        = string
  default     = "secureexample"

  validation {
    condition     = can(regex("^[a-z0-9]+$", var.storage_account_prefix))
    error_message = "Storage account prefix must contain only lowercase letters and numbers."
  }
}

variable "enable_flow_logs" {
  description = "Enable NSG Flow Logs"
  type        = bool
  default     = true
}

variable "enable_defender" {
  description = "Enable Defender for Cloud features"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention days must be between 30 and 730."
  }
}

variable "key_vault_sku" {
  description = "Key Vault SKU"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be either 'standard' or 'premium'."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "secure-example"
    ManagedBy   = "terraform"
    Owner       = "platform-team"
    CostCenter  = "engineering"
  }
}