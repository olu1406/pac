# Basic AWS Landing Zone Example
# This example demonstrates a simple AWS landing zone setup with organization and networking

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# AWS Organization Module
module "organization" {
  source = "../../organization"

  organization_name = var.organization_name
  environment      = var.environment

  # Organization configuration
  create_organization = var.create_organization

  # Security configuration
  security_account_id = var.security_account_id
  external_id        = var.external_id

  # Emergency access
  enable_break_glass_role = var.enable_break_glass_role
  break_glass_users      = var.break_glass_users

  # GuardDuty configuration
  enable_guardduty_s3_export = var.enable_guardduty_s3_export

  tags = var.tags
}

# AWS Networking Module
module "networking" {
  source = "../../networking"

  name_prefix  = var.name_prefix
  environment = var.environment

  # VPC configuration
  hub_vpc_cidr            = var.hub_vpc_cidr
  spoke_vpcs              = var.spoke_vpcs
  availability_zone_count = var.availability_zone_count

  # Security configuration
  management_cidrs = var.management_cidrs

  # Services configuration
  enable_nat_gateway     = var.enable_nat_gateway
  enable_transit_gateway = var.enable_transit_gateway
  enable_flow_logs      = var.enable_flow_logs

  # Flow logs configuration
  flow_logs_destination    = var.flow_logs_destination
  flow_logs_retention_days = var.flow_logs_retention_days

  tags = var.tags

  depends_on = [module.organization]
}