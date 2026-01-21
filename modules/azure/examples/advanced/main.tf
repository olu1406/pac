# Advanced Azure Landing Zone Example
# This example demonstrates a comprehensive Azure landing zone setup with full security features
# Usage: terraform apply -var-file="../environments/prod.tfvars"

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
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
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
  platform_subscription_ids        = var.platform_subscription_ids
  sandbox_subscription_ids          = var.sandbox_subscription_ids

  # Security policies
  create_security_policies = var.create_security_policies
  create_custom_roles      = var.create_custom_roles

  # RBAC configuration
  security_reader_groups   = var.security_reader_groups
  security_operator_groups = var.security_operator_groups
  enable_break_glass_role  = var.enable_break_glass_role
  break_glass_user_ids     = var.break_glass_user_ids

  # Defender for Cloud configuration
  enable_defender_for_cloud    = var.enable_defender_for_cloud
  defender_subscription_ids    = var.defender_subscription_ids
  security_contact_email       = var.security_contact_email
  security_contact_phone       = var.security_contact_phone
  create_log_analytics_workspace = var.create_log_analytics_workspace
  security_resource_group_name = var.security_resource_group_name
  log_retention_days          = var.log_retention_days

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

  # Connectivity configuration
  enable_hub_spoke_peering = var.enable_hub_spoke_peering
  enable_vpn_gateway      = var.enable_vpn_gateway
  vpn_gateway_sku        = var.vpn_gateway_sku
  enable_azure_firewall  = var.enable_azure_firewall
  firewall_sku_tier      = var.firewall_sku_tier
  enable_azure_bastion   = var.enable_azure_bastion

  # Security configuration
  management_cidrs = var.management_cidrs

  # Flow logs configuration
  enable_nsg_flow_logs        = var.enable_nsg_flow_logs
  flow_logs_retention_days    = var.flow_logs_retention_days
  flow_logs_analytics_enabled = var.flow_logs_analytics_enabled

  tags = var.tags

  depends_on = [module.management_groups]
}

# Additional security resources for advanced example

# Key Vault for secrets management
resource "azurerm_resource_group" "security" {
  name     = "${var.name_prefix}-security-rg"
  location = var.location

  tags = var.tags
}

resource "azurerm_key_vault" "main" {
  name                = "${var.name_prefix}-kv-${random_string.kv_suffix.result}"
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  # Security configurations
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = true
  soft_delete_retention_days      = 90

  # Network access restrictions
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    # Allow access from management subnets
    virtual_network_subnet_ids = [
      module.networking.hub_management_subnet_id
    ]
    
    # Allow access from management CIDRs
    ip_rules = var.management_cidrs
  }

  tags = var.tags
}

# Random string for Key Vault name uniqueness
resource "random_string" "kv_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Key Vault access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Recover", "Purge", "GetRotationPolicy", "SetRotationPolicy"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Recover", "Purge"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Import", "Recover", "Purge"
  ]
}

# Storage account for security logs and artifacts
resource "azurerm_storage_account" "security_logs" {
  name                     = "${replace(var.name_prefix, "-", "")}seclogs${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.security.name
  location                 = azurerm_resource_group.security.location
  account_tier             = "Standard"
  account_replication_type = "GRS"  # Geo-redundant for security logs
  account_kind             = "StorageV2"

  # Security configurations
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true

  # Advanced threat protection
  blob_properties {
    delete_retention_policy {
      days = var.log_retention_days
    }
    versioning_enabled = true
  }

  # Network access rules
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    
    # Allow access from management CIDRs
    ip_rules = var.management_cidrs
    
    # Allow access from VNets
    virtual_network_subnet_ids = [
      module.networking.hub_management_subnet_id
    ]
  }

  tags = var.tags
}

# Random string for storage account name uniqueness
resource "random_string" "storage_suffix" {
  length  = 8
  special = false
  upper   = false
}