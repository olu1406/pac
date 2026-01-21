# Variables for Basic AWS Landing Zone Example

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

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

# Organization variables
variable "create_organization" {
  description = "Whether to create AWS Organizations"
  type        = bool
  default     = true
}

variable "security_account_id" {
  description = "AWS account ID for security account"
  type        = string
  default     = ""
}

variable "external_id" {
  description = "External ID for cross-account role assumption"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_break_glass_role" {
  description = "Whether to create break glass role"
  type        = bool
  default     = false
}

variable "break_glass_users" {
  description = "List of IAM user ARNs for break glass access"
  type        = list(string)
  default     = []
}

variable "enable_guardduty_s3_export" {
  description = "Whether to enable GuardDuty S3 export"
  type        = bool
  default     = false
}

# Networking variables
variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "mycompany"
}
variable "hub_vpc_cidr" {
  description = "CIDR block for the hub VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "spoke_vpcs" {
  description = "List of spoke VPC configurations"
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

variable "availability_zone_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "management_cidrs" {
  description = "List of CIDR blocks allowed for management access"
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Whether to create NAT gateways"
  type        = bool
  default     = true
}

variable "enable_transit_gateway" {
  description = "Whether to create Transit Gateway"
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
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Example   = "basic-aws-landing-zone"
  }
}