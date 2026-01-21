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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

provider "azuread" {}

# Generate random suffix for globally unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix     = "${var.project_name}-${var.environment}"
  storage_suffix  = random_id.suffix.hex
  resource_suffix = random_id.suffix.hex
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location

  tags = var.tags
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "${local.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Subnets
resource "azurerm_subnet" "web" {
  name                 = "${local.name_prefix}-web-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 1)]
}

resource "azurerm_subnet" "app" {
  name                 = "${local.name_prefix}-app-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 2)]
}

resource "azurerm_subnet" "data" {
  name                 = "${local.name_prefix}-data-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 3)]
}

# Network Security Groups with secure rules
resource "azurerm_network_security_group" "web" {
  name                = "${local.name_prefix}-web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# SSH access restricted to specific CIDR (satisfies AZ-NET-001)
resource "azurerm_network_security_rule" "web_ssh" {
  name                        = "SSH"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.allowed_ssh_cidr  # Not "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}

# HTTP access from anywhere (common for web servers)
resource "azurerm_network_security_rule" "web_http" {
  name                        = "HTTP"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}

# HTTPS access from anywhere (common for web servers)
resource "azurerm_network_security_rule" "web_https" {
  name                        = "HTTPS"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.web.name
}

# Application tier NSG
resource "azurerm_network_security_group" "app" {
  name                = "${local.name_prefix}-app-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Application access only from web subnet
resource "azurerm_network_security_rule" "app_from_web" {
  name                        = "AppFromWeb"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8080"
  source_address_prefix       = cidrsubnet(var.vnet_cidr, 8, 1)  # Web subnet
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.app.name
}

# Database tier NSG
resource "azurerm_network_security_group" "data" {
  name                = "${local.name_prefix}-data-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# Database access only from app subnet
resource "azurerm_network_security_rule" "data_from_app" {
  name                        = "DataFromApp"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = cidrsubnet(var.vnet_cidr, 8, 2)  # App subnet
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.data.name
}

# Associate NSGs with subnets
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

# Storage Account with full security configuration
resource "azurerm_storage_account" "secure" {
  name                = "${var.storage_account_prefix}${local.storage_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Security configurations (satisfies AZ-DATA-001, AZ-DATA-002, AZ-DATA-005)
  https_traffic_only_enabled   = true   # AZ-DATA-001
  allow_nested_items_to_be_public = false # AZ-DATA-002
  min_tls_version               = "TLS1_2" # AZ-DATA-005

  # Blob soft delete configuration (satisfies AZ-DATA-006)
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Storage Container with private access (satisfies AZ-DATA-003)
resource "azurerm_storage_container" "secure" {
  name                  = "secure-data"
  storage_account_name  = azurerm_storage_account.secure.name
  container_access_type = "private"  # AZ-DATA-003
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days

  tags = var.tags
}

# Key Vault for secrets management
resource "azurerm_key_vault" "main" {
  name                = "${local.name_prefix}-kv-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.key_vault_sku

  # Security configurations
  enabled_for_disk_encryption     = true
  enabled_for_deployment          = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = false  # Set to true in production

  tags = var.tags
}

# Key Vault access policy for current user/service principal
resource "azurerm_key_vault_access_policy" "current" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Purge", "Recover"
  ]

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge", "Recover"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete", "Update", "Purge", "Recover"
  ]
}

# Service Principal for application access
resource "azuread_application" "main" {
  display_name = "${local.name_prefix}-app"

  tags = ["terraform", var.environment, var.project_name]
}

resource "azuread_service_principal" "main" {
  client_id = azuread_application.main.client_id

  tags = ["terraform", var.environment, var.project_name]
}

# Service Principal password with expiration (satisfies AZ-IAM-003)
resource "azuread_application_password" "main" {
  application_object_id = azuread_application.main.object_id
  display_name         = "terraform-managed"
  end_date            = timeadd(timestamp(), "8760h")  # 1 year expiration
}

# Custom RBAC role with specific permissions (satisfies AZ-IAM-001)
resource "azurerm_role_definition" "storage_reader" {
  name        = "${local.name_prefix}-storage-reader"
  scope       = azurerm_resource_group.main.id
  description = "Custom role for reading storage account data"

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.main.id
  ]
}

# Role assignment scoped to resource group (satisfies AZ-IAM-002)
resource "azurerm_role_assignment" "storage_reader" {
  scope              = azurerm_resource_group.main.id  # Not subscription scope
  role_definition_id = azurerm_role_definition.storage_reader.role_definition_resource_id
  principal_id       = azuread_service_principal.main.object_id
}

# NSG Flow Logs (if enabled)
resource "azurerm_network_watcher_flow_log" "web" {
  count = var.enable_flow_logs ? 1 : 0

  name                 = "${var.project_name}-${var.environment}-web-flow-log"
  network_watcher_name = "NetworkWatcher_${lower(replace(var.location, " ", ""))}"
  resource_group_name  = "NetworkWatcherRG"

  network_security_group_id = azurerm_network_security_group.web.id
  storage_account_id        = azurerm_storage_account.secure.id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 7
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.main.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.main.location
    workspace_resource_id = azurerm_log_analytics_workspace.main.id
    interval_in_minutes   = 10
  }

  tags = var.tags
}

# Public IP for testing (with proper NSG restrictions)
resource "azurerm_public_ip" "test" {
  name                = "${local.name_prefix}-test-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}