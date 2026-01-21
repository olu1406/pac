# Variables for AWS Networking Baseline Module

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

variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(cidrhost(var.hub_vpc_cidr, 0))
    error_message = "Hub VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "spoke_vpcs" {
  description = "List of spoke VPC configurations"
  type = list(object({
    name         = string
    cidr_block   = string
    allowed_ports = optional(list(number))
  }))
  default = []
  validation {
    condition = alltrue([
      for vpc in var.spoke_vpcs : can(cidrhost(vpc.cidr_block, 0))
    ])
    error_message = "All spoke VPC CIDR blocks must be valid IPv4 CIDR blocks."
  }
}

variable "availability_zone_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
  validation {
    condition     = var.availability_zone_count >= 2 && var.availability_zone_count <= 6
    error_message = "Availability zone count must be between 2 and 6."
  }
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways for private subnet internet access"
  type        = bool
  default     = true
}

variable "enable_transit_gateway" {
  description = "Whether to create Transit Gateway for hub-spoke connectivity"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Whether to enable VPC Flow Logs"
  type        = bool
  default     = true
}

variable "flow_logs_destination" {
  description = "Destination for VPC Flow Logs (s3 or cloudwatch)"
  type        = string
  default     = "s3"
  validation {
    condition     = contains(["s3", "cloudwatch"], var.flow_logs_destination)
    error_message = "Flow logs destination must be either 's3' or 'cloudwatch'."
  }
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 365
  validation {
    condition     = var.flow_logs_retention_days > 0
    error_message = "Flow logs retention days must be greater than 0."
  }
}

variable "flow_logs_format" {
  description = "Format for VPC Flow Logs"
  type        = string
  default     = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${windowstart} $${windowend} $${action} $${flowlogstatus}"
}

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

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Module    = "aws-networking-baseline"
  }
}