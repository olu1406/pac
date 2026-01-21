variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "secure-advanced"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.1.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
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

variable "allowed_https_cidrs" {
  description = "CIDR blocks allowed for HTTPS access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Public web access

  validation {
    condition = alltrue([
      for cidr in var.allowed_https_cidrs : can(cidrhost(cidr, 0))
    ])
    error_message = "All HTTPS CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "cross_account_role_arns" {
  description = "List of cross-account role ARNs allowed to assume roles"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.cross_account_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/.+", arn))
    ])
    error_message = "Cross-account role ARNs must be valid IAM role ARNs."
  }
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket names (must be globally unique)"
  type        = string
  default     = "secure-advanced"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.s3_bucket_prefix))
    error_message = "S3 bucket prefix must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "backup_region" {
  description = "AWS region for cross-region backups"
  type        = string
  default     = "us-west-2"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.backup_region))
    error_message = "Backup region must be a valid AWS region identifier."
  }
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config compliance monitoring"
  type        = bool
  default     = true
}

variable "enable_security_hub" {
  description = "Enable AWS Security Hub"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services"
  type        = bool
  default     = true
}

variable "kms_key_rotation" {
  description = "Enable automatic KMS key rotation"
  type        = bool
  default     = true
}

variable "cloudtrail_data_events" {
  description = "Enable CloudTrail data events logging"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment   = "prod"
    Project       = "secure-advanced"
    ManagedBy     = "terraform"
    Compliance    = "required"
    DataClass     = "confidential"
    BackupPolicy  = "daily"
  }
}