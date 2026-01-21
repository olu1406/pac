# Azure Networking Baseline Module
# Implements secure VNet setup with hub-spoke topology and NSG baselines

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

# Resource group for networking resources
resource "azurerm_resource_group" "networking" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "${var.name_prefix}-hub-vnet"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.hub_vnet_cidr]

  tags = merge(var.tags, {
    Type = "Hub"
  })
}

# Hub VNet subnets
resource "azurerm_subnet" "hub_gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 8, 0)]
}

resource "azurerm_subnet" "hub_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 8, 1)]
}

resource "azurerm_subnet" "hub_bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 8, 2)]
}

resource "azurerm_subnet" "hub_management" {
  name                 = "${var.name_prefix}-hub-management-subnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_vnet_cidr, 8, 10)]

  # Enable service endpoints
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Sql"
  ]
}

# Spoke Virtual Networks
resource "azurerm_virtual_network" "spoke" {
  count = length(var.spoke_vnets)

  name                = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-vnet"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  address_space       = [var.spoke_vnets[count.index].cidr_block]

  tags = merge(var.tags, {
    Type = "Spoke"
    Name = var.spoke_vnets[count.index].name
  })
}

# Spoke VNet subnets
resource "azurerm_subnet" "spoke_app" {
  count = length(var.spoke_vnets)

  name                 = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-app-subnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.spoke[count.index].name
  address_prefixes     = [cidrsubnet(var.spoke_vnets[count.index].cidr_block, 8, 0)]

  # Enable service endpoints
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Sql"
  ]
}

resource "azurerm_subnet" "spoke_data" {
  count = length(var.spoke_vnets)

  name                 = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-data-subnet"
  resource_group_name  = azurerm_resource_group.networking.name
  virtual_network_name = azurerm_virtual_network.spoke[count.index].name
  address_prefixes     = [cidrsubnet(var.spoke_vnets[count.index].cidr_block, 8, 1)]

  # Enable service endpoints for data services
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.KeyVault",
    "Microsoft.Sql",
    "Microsoft.AzureCosmosDB"
  ]
}
# VNet Peering - Hub to Spoke
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count = var.enable_hub_spoke_peering ? length(var.spoke_vnets) : 0

  name                      = "${var.name_prefix}-hub-to-${var.spoke_vnets[count.index].name}"
  resource_group_name       = azurerm_resource_group.networking.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[count.index].id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  use_remote_gateways          = false
}

# VNet Peering - Spoke to Hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = var.enable_hub_spoke_peering ? length(var.spoke_vnets) : 0

  name                      = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-to-hub"
  resource_group_name       = azurerm_resource_group.networking.name
  virtual_network_name      = azurerm_virtual_network.spoke[count.index].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = var.enable_vpn_gateway
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                = "${var.name_prefix}-vpn-gateway-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# VPN Gateway
resource "azurerm_virtual_network_gateway" "vpn" {
  count = var.enable_vpn_gateway ? 1 : 0

  name                = "${var.name_prefix}-vpn-gateway"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = var.vpn_gateway_sku

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway.id
  }

  tags = var.tags
}

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  count = var.enable_azure_firewall ? 1 : 0

  name                = "${var.name_prefix}-firewall-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  count = var.enable_azure_firewall ? 1 : 0

  name                = "${var.name_prefix}-firewall"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }

  tags = var.tags
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "main" {
  count = var.enable_azure_firewall ? 1 : 0

  name                = "${var.name_prefix}-firewall-policy"
  resource_group_name = azurerm_resource_group.networking.name
  location            = azurerm_resource_group.networking.location

  threat_intelligence_mode = "Alert"

  tags = var.tags
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "main" {
  count = var.enable_azure_firewall ? 1 : 0

  name               = "${var.name_prefix}-firewall-rules"
  firewall_policy_id = azurerm_firewall_policy.main[0].id
  priority           = 500

  # Network rule collection for basic connectivity
  network_rule_collection {
    name     = "network-rules"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["168.63.129.16", "8.8.8.8", "8.8.4.4"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  # Application rule collection for web traffic
  application_rule_collection {
    name     = "application-rules"
    priority = 500
    action   = "Allow"

    rule {
      name = "allow-web"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = ["*"]
      destination_fqdns = ["*"]
    }
  }
}

# Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion" {
  count = var.enable_azure_bastion ? 1 : 0

  name                = "${var.name_prefix}-bastion-pip"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  count = var.enable_azure_bastion ? 1 : 0

  name                = "${var.name_prefix}-bastion"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.hub_bastion.id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }

  tags = var.tags
}