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
  features {}
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
data "azurerm_subscription" "current" {}

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

# Subnet
resource "azurerm_subnet" "main" {
  name                 = "${local.name_prefix}-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [cidrsubnet(var.vnet_cidr, 8, 1)]
}

# VIOLATION AZ-NET-004: Network Security Group with no custom rules
resource "azurerm_network_security_group" "empty" {
  name                = "${local.name_prefix}-empty-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # VIOLATION: No security_rule blocks defined
  # This violates AZ-NET-004 which requires custom rules

  tags = var.tags
}

# VIOLATION AZ-NET-001, AZ-NET-002, AZ-NET-003, AZ-NET-005: Insecure NSG rules
resource "azurerm_network_security_group" "insecure" {
  name                = "${local.name_prefix}-insecure-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = var.tags
}

# VIOLATION AZ-NET-001: SSH access from any source
resource "azurerm_network_security_rule" "ssh_from_anywhere" {
  name                        = "SSH-Insecure"
  priority                    = 1001
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"  # VIOLATION: Should be restricted
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.insecure.name
}

# VIOLATION AZ-NET-002: RDP access from any source
resource "azurerm_network_security_rule" "rdp_from_anywhere" {
  name                        = "RDP-Insecure"
  priority                    = 1002
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "*"  # VIOLATION: Should be restricted
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.insecure.name
}

# VIOLATION AZ-NET-003: Unrestricted inbound access to all ports
resource "azurerm_network_security_rule" "unrestricted_inbound" {
  name                        = "AllowAll-Insecure"
  priority                    = 1003
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"  # VIOLATION: All ports
  source_address_prefix       = "*"  # VIOLATION: Any source
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.insecure.name
}

# VIOLATION AZ-NET-005: High-risk port (MySQL) accessible from anywhere
resource "azurerm_network_security_rule" "mysql_from_anywhere" {
  name                        = "MySQL-Insecure"
  priority                    = 1004
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"  # High-risk port
  source_address_prefix       = "*"     # VIOLATION: Should be restricted
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.insecure.name
}

# Associate NSG with subnet
resource "azurerm_subnet_network_security_group_association" "main" {
  subnet_id                 = azurerm_subnet.main.id
  network_security_group_id = azurerm_network_security_group.insecure.id
}

# VIOLATION AZ-DATA-001, AZ-DATA-002, AZ-DATA-005, AZ-DATA-006: Insecure Storage Account
resource "azurerm_storage_account" "insecure" {
  name                = "${var.storage_account_prefix}${local.storage_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  # VIOLATIONS:
  enable_https_traffic_only      = false # AZ-DATA-001: Should be true
  allow_nested_items_to_be_public = true  # AZ-DATA-002: Should be false
  min_tls_version               = "TLS1_0" # AZ-DATA-005: Should be TLS1_2

  # AZ-DATA-006: No blob_properties block (no soft delete)

  tags = var.tags
}

# VIOLATION AZ-DATA-003: Storage Container with public access
resource "azurerm_storage_container" "public" {
  name                  = "public-data"
  storage_account_name  = azurerm_storage_account.insecure.name
  container_access_type = "blob"  # VIOLATION: Should be "private"
}

# Service Principal for testing IAM violations
resource "azuread_application" "insecure" {
  display_name = "${local.name_prefix}-insecure-app"

  tags = ["terraform", var.environment, var.project_name]
}

resource "azuread_service_principal" "insecure" {
  application_id = azuread_application.insecure.application_id

  tags = ["terraform", var.environment, var.project_name]
}

# VIOLATION AZ-IAM-003: Service Principal password without expiration
resource "azuread_application_password" "insecure" {
  application_object_id = azuread_application.insecure.object_id
  display_name         = "terraform-managed-insecure"
  # VIOLATION: No end_date specified (permanent credential)
}

# VIOLATION AZ-IAM-001: Custom RBAC role with wildcard permissions
resource "azurerm_role_definition" "wildcard_role" {
  name        = "${local.name_prefix}-wildcard-role"
  scope       = azurerm_resource_group.main.id
  description = "Custom role with wildcard permissions - INSECURE"

  permissions {
    actions = [
      "*"  # VIOLATION: Wildcard action
    ]
    not_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.main.id
  ]
}

# VIOLATION AZ-IAM-002: Owner role assignment at subscription scope (if subscription_id provided)
resource "azurerm_role_assignment" "subscription_owner" {
  count = var.subscription_id != "" ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}"  # VIOLATION: Subscription scope
  role_definition_name = "Owner"                                 # VIOLATION: Owner role
  principal_id         = azuread_service_principal.insecure.object_id
}

# VIOLATION AZ-IAM-005: Privileged role assignment (Security Administrator)
resource "azurerm_role_assignment" "security_admin" {
  scope                = azurerm_resource_group.main.id
  role_definition_name = "Security Administrator"  # Privileged role
  principal_id         = azuread_service_principal.insecure.object_id
}

# Assign the wildcard role
resource "azurerm_role_assignment" "wildcard_assignment" {
  scope              = azurerm_resource_group.main.id
  role_definition_id = azurerm_role_definition.wildcard_role.role_definition_resource_id
  principal_id       = azuread_service_principal.insecure.object_id
}

# Additional storage account to demonstrate more violations
resource "azurerm_storage_account" "more_violations" {
  name                = "${var.storage_account_prefix}2${local.storage_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  # More violations
  enable_https_traffic_only      = false  # AZ-DATA-001
  allow_nested_items_to_be_public = true   # AZ-DATA-002
  min_tls_version               = "TLS1_1" # AZ-DATA-005

  tags = var.tags
}

# Public IP for testing
resource "azurerm_public_ip" "test" {
  name                = "${local.name_prefix}-test-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}