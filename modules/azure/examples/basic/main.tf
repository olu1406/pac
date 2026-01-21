# Basic Azure Landing Zone Example
# This example demonstrates a simple Azure landing zone setup with management groups and networking
# Usage: terraform apply -var-file="../environments/dev.tfvars"

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
  source = "../../management-groups"

  organization_name = var.organization_name
  environment      = var.environment
  location         = var.location

  # Management group configuration
  create_management_group_hierarchy = var.create_management_group_hierarchy
  security_subscription_ids         = var.security_subscription_ids
  workload_subscription_ids         = var.workload_subscription_ids

  # Security configuration
  enable_defender_for_cloud       = var.enable_defender_for_cloud
  security_contact_email          = var.security_contact_email
  create_log_analytics_workspace  = var.create_log_analytics_workspace

  # RBAC configuration
  security_reader_groups = var.security_reader_groups

  tags = var.tags
}

# Azure Networking Module
module "networking" {
  source = "../../networking"

  name_prefix         = var.name_prefix
  environment        = var.environment
  location           = var.location
  resource_group_name = var.resource_group_name

  # VNet configuration
  hub_vnet_cidr = var.hub_vnet_cidr
  spoke_vnets   = var.spoke_vnets

  # Security configuration
  management_cidrs = var.management_cidrs

  # Services configuration
  enable_hub_spoke_peering = var.enable_hub_spoke_peering
  enable_azure_bastion     = var.enable_azure_bastion
  enable_nsg_flow_logs     = var.enable_nsg_flow_logs

  tags = var.tags

  depends_on = [module.management_groups]
}