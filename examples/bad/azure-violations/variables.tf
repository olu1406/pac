variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "test"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "insecure-example"
}

variable "location" {
  description = "Azure region for resource deployment"
  type        = string
  default     = "East US"
}

variable "vnet_cidr" {
  description = "CIDR block for Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "storage_account_prefix" {
  description = "Prefix for storage account names"
  type        = string
  default     = "insecuretest"
}

variable "subscription_id" {
  description = "Azure subscription ID for testing subscription-level assignments"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "test"
    Project     = "insecure-example"
    ManagedBy   = "terraform"
    Purpose     = "security-testing"
    Warning     = "intentionally-insecure"
  }
}