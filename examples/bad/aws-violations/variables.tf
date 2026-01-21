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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "s3_bucket_prefix" {
  description = "Prefix for S3 bucket names"
  type        = string
  default     = "insecure-example"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "test"
    Project     = "insecure-example"
    ManagedBy   = "terraform"
    Purpose     = "security-testing"
  }
}