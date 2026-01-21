# Example: Using Azure Landing Zone with Environment Files
# This demonstrates how to use the Azure landing zone modules with environment-specific configurations

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {}
}

provider "azuread" {}

# Azure Management Groups Module
module "management_groups" {
  source = "../management-groups"

  # All variables come from environment files
  organization_name                     = var.organization_name
  environment                          = var.environment
  location                            = var.location
  create_management_group_hierarchy    = var.create_management_group_hierarchy
  existing_root_management_group_id    = var.existing_root_management_group_id
  existing_security_management_group_id = var.existing_security_management_group_id
  root_subscription_ids               = var.root_subscription_ids
  security_subscription_ids           = var.security_subscription_ids
  workload_subscription_ids           = var.workload_subscription_ids
  platform_subscription_ids          = var.platform_subscription_ids
  sandbox_subscription_ids            = var.sandbox_subscription_ids
  create_security_policies            = var.create_security_policies
  create_custom_roles                 = var.create_custom_roles
  security_reader_groups              = var.security_reader_groups
  security_operator_groups            = var.security_operator_groups
  enable_break_glass_role             = var.enable_break_glass_role
  break_glass_user_ids                = var.break_glass_user_ids
  enable_defender_for_cloud           = var.enable_defender_for_cloud
  defender_subscription_ids           = var.defender_subscription_ids
  security_contact_email              = var.security_contact_email
  security_contact_phone              = var.security_contact_phone
  create_log_analytics_workspace      = var.create_log_analytics_workspace
  security_resource_group_name        = var.security_resource_group_name
  log_retention_days                  = var.log_retention_days
  tags                               = var.tags
}

# Azure Networking Module
module "networking" {
  source = "../networking"

  # All variables come from environment files
  name_prefix                     = var.name_prefix
  environment                    = var.environment
  location                       = var.location
  resource_group_name            = var.resource_group_name
  hub_vnet_cidr                  = var.hub_vnet_cidr
  spoke_vnets                    = var.spoke_vnets
  enable_hub_spoke_peering       = var.enable_hub_spoke_peering
  enable_vpn_gateway             = var.enable_vpn_gateway
  vpn_gateway_sku               = var.vpn_gateway_sku
  enable_azure_firewall         = var.enable_azure_firewall
  firewall_sku_tier             = var.firewall_sku_tier
  enable_azure_bastion          = var.enable_azure_bastion
  management_cidrs              = var.management_cidrs
  enable_nsg_flow_logs          = var.enable_nsg_flow_logs
  flow_logs_retention_days      = var.flow_logs_retention_days
  flow_logs_analytics_enabled   = var.flow_logs_analytics_enabled
  tags                          = var.tags

  depends_on = [module.management_groups]
}

# Usage Examples:
#
# Development Environment:
# terraform apply -var-file="environments/dev.tfvars"
#
# Test Environment:
# terraform apply -var-file="environments/test.tfvars"
#
# Production Environment:
# terraform apply -var-file="environments/prod.tfvars"
#
# The environment files contain all the necessary variable values
# optimized for each environment's specific requirements.