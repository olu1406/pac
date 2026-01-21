# Azure Networking Baseline Module

This Terraform module creates a secure Azure networking foundation with hub-spoke topology, Network Security Groups (NSGs), and comprehensive network monitoring. It implements security best practices and provides a scalable network architecture for enterprise Azure deployments.

## Features

- **Hub-Spoke Topology**: Centralized hub VNet with multiple spoke VNets for workload isolation
- **Network Security Groups**: Baseline NSG rules with default-deny and least-privilege access
- **NSG Flow Logs**: Comprehensive network traffic logging and analytics
- **Azure Firewall**: Optional centralized network security and filtering
- **Azure Bastion**: Secure remote access without exposing VMs to the internet
- **VPN Gateway**: Hybrid connectivity for on-premises integration
- **Traffic Analytics**: Advanced network monitoring and threat detection

## Architecture

```
Hub VNet (10.0.0.0/16)
├── GatewaySubnet (10.0.0.0/24) - VPN Gateway
├── AzureFirewallSubnet (10.0.1.0/24) - Azure Firewall
├── AzureBastionSubnet (10.0.2.0/24) - Azure Bastion
└── Management Subnet (10.0.10.0/24) - Management VMs

Spoke VNets
├── App Subnet - Application tier
└── Data Subnet - Database tier
```

## Usage

### Basic Hub-Spoke Configuration

```hcl
module "azure_networking" {
  source = "./modules/azure/networking"

  name_prefix         = "contoso"
  environment        = "prod"
  location           = "East US"
  resource_group_name = "rg-networking-prod"

  # Hub VNet configuration
  hub_vnet_cidr = "10.0.0.0/16"

  # Spoke VNets configuration
  spoke_vnets = [
    {
      name       = "web"
      cidr_block = "10.1.0.0/16"
      allowed_ports = [80, 443]
    },
    {
      name       = "api"
      cidr_block = "10.2.0.0/16"
      allowed_ports = [8080, 8443]
    }
  ]

  # Security configuration
  management_cidrs = ["203.0.113.0/24"]
  
  # Enable basic services
  enable_hub_spoke_peering = true
  enable_azure_bastion     = true
  enable_nsg_flow_logs     = true

  tags = {
    Environment = "Production"
    Owner       = "Platform Team"
  }
}
```

### Advanced Configuration with Firewall and VPN

```hcl
module "azure_networking" {
  source = "./modules/azure/networking"

  name_prefix         = "contoso"
  environment        = "prod"
  location           = "East US"
  resource_group_name = "rg-networking-prod"

  # Hub VNet configuration
  hub_vnet_cidr = "10.0.0.0/16"

  # Spoke VNets configuration
  spoke_vnets = [
    {
      name          = "web"
      cidr_block    = "10.1.0.0/16"
      allowed_ports = [80, 443]
    },
    {
      name          = "api"
      cidr_block    = "10.2.0.0/16"
      allowed_ports = [8080, 8443]
    },
    {
      name          = "data"
      cidr_block    = "10.3.0.0/16"
      allowed_ports = null
    }
  ]

  # Connectivity configuration
  enable_hub_spoke_peering = true
  enable_vpn_gateway       = true
  vpn_gateway_sku         = "VpnGw2"
  enable_azure_firewall   = true
  firewall_sku_tier       = "Premium"
  enable_azure_bastion    = true

  # Security configuration
  management_cidrs = [
    "203.0.113.0/24",  # Corporate network
    "198.51.100.0/24"  # VPN users
  ]

  # Flow logs configuration
  enable_nsg_flow_logs        = true
  flow_logs_retention_days    = 180
  flow_logs_analytics_enabled = true

  tags = {
    Environment        = "Production"
    Owner             = "Platform Team"
    ComplianceFramework = "NIST-800-53"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |
| random | n/a |

## Resources Created

### Networking
- Hub Virtual Network with specialized subnets
- Spoke Virtual Networks with application and data tiers
- VNet peering connections (hub-spoke topology)
- Route tables and user-defined routes

### Security
- Network Security Groups with baseline rules
- NSG Flow Logs with Traffic Analytics
- Azure Firewall with policy-based rules (optional)
- Azure Bastion for secure remote access (optional)

### Connectivity
- VPN Gateway for hybrid connectivity (optional)
- Public IP addresses for gateways and services
- Network Watcher for monitoring and diagnostics

### Storage & Analytics
- Storage account for NSG Flow Logs
- Log Analytics workspace for Traffic Analytics
- Network monitoring and alerting

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for resource names | `string` | n/a | yes |
| location | Azure region for resources | `string` | `"East US"` | no |
| hub_vnet_cidr | CIDR block for the hub VNet | `string` | `"10.0.0.0/16"` | no |
| spoke_vnets | List of spoke VNet configurations | `list(object)` | `[]` | no |
| management_cidrs | CIDR blocks allowed for management access | `list(string)` | `[]` | no |
| enable_nsg_flow_logs | Whether to enable NSG Flow Logs | `bool` | `true` | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| hub_vnet_id | ID of the hub VNet |
| spoke_vnet_ids | IDs of the spoke VNets |
| hub_management_nsg_id | ID of the hub management NSG |
| azure_firewall_private_ip | Private IP of Azure Firewall |
| flow_logs_storage_account_name | Name of Flow Logs storage account |

See [outputs.tf](./outputs.tf) for complete list of outputs.

## Security Considerations

### Network Segmentation
- Hub-spoke topology provides centralized security controls
- Application and data tiers are separated in different subnets
- NSGs implement micro-segmentation with least-privilege access

### Default Security Posture
- All NSGs have default-deny inbound rules
- Management access restricted to specific CIDR blocks
- Inter-VNet communication controlled through peering and NSG rules

### Monitoring and Logging
- NSG Flow Logs capture all network traffic
- Traffic Analytics provides security insights and threat detection
- Network Watcher enables advanced diagnostics

### Compliance Framework Mapping
- Implements network controls for NIST 800-53
- Supports ISO 27001 network security requirements
- Follows CIS Azure Foundations Benchmark networking controls

## Network Security Groups (NSG) Rules

### Hub Management NSG
- Allow SSH/RDP from management CIDRs
- Allow Azure Load Balancer health probes
- Deny all other inbound traffic

### Spoke Application NSG
- Allow traffic from hub management subnet
- Allow HTTP/HTTPS from Azure Load Balancer
- Allow specific application ports from VNet
- Deny all other inbound traffic

### Spoke Data NSG
- Allow traffic from application subnet in same spoke
- Allow traffic from hub management subnet
- Allow Azure Load Balancer health probes
- Deny all other inbound traffic

## Examples

See the [examples](../examples/) directory for complete usage examples:
- [Basic hub-spoke setup](../examples/basic/)
- [Advanced enterprise configuration](../examples/advanced/)

## Contributing

Please read [CONTRIBUTING.md](../../../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This module is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.