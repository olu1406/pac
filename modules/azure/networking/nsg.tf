# Network Security Groups and Rules
# Hub Management NSG
resource "azurerm_network_security_group" "hub_management" {
  name                = "${var.name_prefix}-hub-management-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  # Deny all inbound by default (implicit)
  # Allow management access from specific CIDRs
  dynamic "security_rule" {
    for_each = var.management_cidrs
    content {
      name                       = "allow-management-${security_rule.key}"
      priority                   = 1000 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_ranges    = ["22", "3389"]
      source_address_prefix      = security_rule.value
      destination_address_prefix = "*"
    }
  }

  # Allow Azure Load Balancer health probes
  security_rule {
    name                       = "allow-azure-lb"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

# Hub Management NSG Association
resource "azurerm_subnet_network_security_group_association" "hub_management" {
  subnet_id                 = azurerm_subnet.hub_management.id
  network_security_group_id = azurerm_network_security_group.hub_management.id
}

# Spoke Application NSGs
resource "azurerm_network_security_group" "spoke_app" {
  count = length(var.spoke_vnets)

  name                = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-app-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  # Allow traffic from hub management subnet
  security_rule {
    name                       = "allow-hub-management"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = cidrsubnet(var.hub_vnet_cidr, 8, 10)
    destination_address_prefix = "*"
  }

  # Allow HTTP/HTTPS from Azure Load Balancer
  security_rule {
    name                       = "allow-web-from-lb"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow specific application ports if defined
  dynamic "security_rule" {
    for_each = var.spoke_vnets[count.index].allowed_ports != null ? var.spoke_vnets[count.index].allowed_ports : []
    content {
      name                       = "allow-app-port-${security_rule.value}"
      priority                   = 1200 + security_rule.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = tostring(security_rule.value)
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  }

  # Allow Azure Load Balancer health probes
  security_rule {
    name                       = "allow-azure-lb"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    Spoke = var.spoke_vnets[count.index].name
  })
}

# Spoke Application NSG Associations
resource "azurerm_subnet_network_security_group_association" "spoke_app" {
  count = length(var.spoke_vnets)

  subnet_id                 = azurerm_subnet.spoke_app[count.index].id
  network_security_group_id = azurerm_network_security_group.spoke_app[count.index].id
}

# Spoke Data NSGs
resource "azurerm_network_security_group" "spoke_data" {
  count = length(var.spoke_vnets)

  name                = "${var.name_prefix}-${var.spoke_vnets[count.index].name}-data-nsg"
  location            = azurerm_resource_group.networking.location
  resource_group_name = azurerm_resource_group.networking.name

  # Allow traffic from application subnet in same spoke
  security_rule {
    name                       = "allow-app-subnet"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = cidrsubnet(var.spoke_vnets[count.index].cidr_block, 8, 0)
    destination_address_prefix = "*"
  }

  # Allow traffic from hub management subnet
  security_rule {
    name                       = "allow-hub-management"
    priority                   = 1100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = cidrsubnet(var.hub_vnet_cidr, 8, 10)
    destination_address_prefix = "*"
  }

  # Allow Azure Load Balancer health probes
  security_rule {
    name                       = "allow-azure-lb"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge(var.tags, {
    Spoke = var.spoke_vnets[count.index].name
  })
}

# Spoke Data NSG Associations
resource "azurerm_subnet_network_security_group_association" "spoke_data" {
  count = length(var.spoke_vnets)

  subnet_id                 = azurerm_subnet.spoke_data[count.index].id
  network_security_group_id = azurerm_network_security_group.spoke_data[count.index].id
}