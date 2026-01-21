# AWS Networking Baseline Module

This Terraform module creates a secure AWS networking foundation with hub-spoke topology, Transit Gateway connectivity, security group baselines, and comprehensive VPC Flow Logs.

## Features

- **Hub-Spoke Architecture**: Centralized hub VPC with multiple spoke VPCs for workload isolation
- **Transit Gateway**: Scalable connectivity between VPCs with proper route segmentation
- **Security Groups**: Baseline security groups with least-privilege access patterns
- **VPC Flow Logs**: Comprehensive network traffic logging for security monitoring
- **NAT Gateways**: Secure outbound internet access for private subnets
- **Multi-AZ Design**: High availability across multiple availability zones

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Hub VPC                              │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │  Public Subnet  │              │  Public Subnet  │      │
│  │     (AZ-1)      │              │     (AZ-2)      │      │
│  │   NAT Gateway   │              │   NAT Gateway   │      │
│  └─────────────────┘              └─────────────────┘      │
│  ┌─────────────────┐              ┌─────────────────┐      │
│  │ Private Subnet  │              │ Private Subnet  │      │
│  │     (AZ-1)      │              │     (AZ-2)      │      │
│  └─────────────────┘              └─────────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────────────┐
                    │ Transit Gateway │
                    └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│   Spoke VPC   │    │   Spoke VPC   │    │   Spoke VPC   │
│  (Workload A) │    │  (Workload B) │    │  (Workload C) │
└───────────────┘    └───────────────┘    └───────────────┘
```

## Security Controls

### Network Segmentation
- Hub VPC for shared services and internet connectivity
- Spoke VPCs for workload isolation
- Transit Gateway with separate route tables per spoke
- No direct spoke-to-spoke communication by default

### Security Groups
- **Default Deny**: All security groups start with no inbound rules
- **Least Privilege**: Minimal required access patterns
- **Layered Security**: Web, application, and database tiers
- **Management Access**: Restricted SSH/RDP from management networks

### Traffic Monitoring
- VPC Flow Logs for all VPCs and subnets
- Encrypted storage in S3 or CloudWatch Logs
- Configurable retention and lifecycle policies
- Parquet format for efficient analysis

## Usage

### Basic Hub-Spoke Setup

```hcl
module "aws_networking" {
  source = "./modules/aws/networking"

  name_prefix = "mycompany"
  environment = "prod"
  
  hub_vpc_cidr = "10.0.0.0/16"
  
  spoke_vpcs = [
    {
      name       = "web"
      cidr_block = "10.1.0.0/16"
      allowed_ports = [80, 443, 8080]
    },
    {
      name       = "app"
      cidr_block = "10.2.0.0/16"
      allowed_ports = [8080, 9090]
    },
    {
      name       = "data"
      cidr_block = "10.3.0.0/16"
    }
  ]
  
  management_cidrs = ["203.0.113.0/24"]
  
  tags = {
    Environment = "prod"
    Owner       = "platform-team"
  }
}
```

### Advanced Configuration

```hcl
module "aws_networking" {
  source = "./modules/aws/networking"

  name_prefix = "mycompany"
  environment = "prod"
  
  # Network configuration
  hub_vpc_cidr          = "10.0.0.0/16"
  availability_zone_count = 3
  
  spoke_vpcs = [
    {
      name       = "web-tier"
      cidr_block = "10.1.0.0/16"
      allowed_ports = [80, 443]
    },
    {
      name       = "app-tier"
      cidr_block = "10.2.0.0/16"
      allowed_ports = [8080, 9090, 3000]
    },
    {
      name       = "data-tier"
      cidr_block = "10.3.0.0/16"
    }
  ]
  
  # Connectivity options
  enable_nat_gateway      = true
  enable_transit_gateway  = true
  
  # Flow logs configuration
  enable_flow_logs           = true
  flow_logs_destination      = "s3"
  flow_logs_retention_days   = 730
  
  # Management access
  management_cidrs = [
    "203.0.113.0/24",  # Office network
    "198.51.100.0/24"  # VPN network
  ]
  
  tags = {
    Environment   = "prod"
    Owner         = "platform-team"
    Compliance    = "SOC2"
    CostCenter    = "infrastructure"
  }
}
```

### Development Environment

```hcl
module "aws_networking_dev" {
  source = "./modules/aws/networking"

  name_prefix = "mycompany-dev"
  environment = "dev"
  
  hub_vpc_cidr          = "10.10.0.0/16"
  availability_zone_count = 2
  
  spoke_vpcs = [
    {
      name       = "dev-app"
      cidr_block = "10.11.0.0/16"
      allowed_ports = [3000, 8080]
    }
  ]
  
  # Cost optimization for dev
  enable_nat_gateway     = false  # Use single NAT or no NAT
  flow_logs_retention_days = 30   # Shorter retention
  
  management_cidrs = ["0.0.0.0/0"]  # More permissive for dev
  
  tags = {
    Environment = "dev"
    Owner       = "dev-team"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | ~> 5.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| random | n/a |

## Resources Created

### VPC Resources
- `aws_vpc` - Hub and spoke VPCs
- `aws_subnet` - Public and private subnets across AZs
- `aws_internet_gateway` - Internet access for hub VPC
- `aws_nat_gateway` - Outbound internet access for private subnets
- `aws_route_table` - Route tables for proper traffic routing
- `aws_route_table_association` - Subnet to route table associations

### Transit Gateway Resources
- `aws_ec2_transit_gateway` - Central connectivity hub
- `aws_ec2_transit_gateway_vpc_attachment` - VPC attachments
- `aws_ec2_transit_gateway_route_table` - Separate route tables per spoke
- `aws_ec2_transit_gateway_route` - Routes between hub and spokes

### Security Resources
- `aws_security_group` - Baseline security groups for each tier
- `aws_flow_log` - VPC Flow Logs for traffic monitoring
- `aws_s3_bucket` - Flow logs storage with encryption
- `aws_kms_key` - Encryption keys for flow logs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name_prefix | Prefix for resource names | `string` | n/a | yes |
| environment | Environment name | `string` | `"prod"` | no |
| hub_vpc_cidr | CIDR block for hub VPC | `string` | `"10.0.0.0/16"` | no |
| spoke_vpcs | List of spoke VPC configurations | `list(object)` | `[]` | no |
| availability_zone_count | Number of AZs to use | `number` | `2` | no |
| enable_nat_gateway | Whether to create NAT gateways | `bool` | `true` | no |
| enable_transit_gateway | Whether to create Transit Gateway | `bool` | `true` | no |
| enable_flow_logs | Whether to enable VPC Flow Logs | `bool` | `true` | no |
| flow_logs_destination | Flow logs destination (s3/cloudwatch) | `string` | `"s3"` | no |
| flow_logs_retention_days | Flow logs retention period | `number` | `365` | no |
| management_cidrs | Management access CIDR blocks | `list(string)` | `[]` | no |
| tags | Tags to apply to resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| hub_vpc_id | ID of the hub VPC |
| spoke_vpc_ids | IDs of the spoke VPCs |
| transit_gateway_id | ID of the Transit Gateway |
| hub_default_security_group_id | ID of hub default security group |
| spoke_default_security_group_ids | IDs of spoke default security groups |
| flow_logs_s3_bucket | S3 bucket for flow logs |

## Security Considerations

1. **Network Isolation**: Spoke VPCs are isolated by default
2. **Least Privilege**: Security groups follow minimal access principles
3. **Traffic Monitoring**: All network traffic is logged
4. **Encryption**: Flow logs are encrypted at rest
5. **Management Access**: SSH/RDP restricted to management networks

## Cost Optimization

- **NAT Gateways**: ~$45/month per gateway + data transfer costs
- **Transit Gateway**: $36/month + attachment and data processing costs
- **Flow Logs**: S3 storage costs + data ingestion costs
- **Development**: Disable NAT gateways and use shorter retention for cost savings

## Compliance Frameworks

This module supports:
- **CIS AWS Foundations Benchmark**
- **NIST Cybersecurity Framework**
- **SOC 2 Type II**
- **PCI DSS** (with additional controls)

## Troubleshooting

### Common Issues

1. **CIDR Conflicts**: Ensure hub and spoke CIDRs don't overlap
2. **Route Propagation**: Check Transit Gateway route tables
3. **Security Group Rules**: Verify security group references
4. **Flow Logs Permissions**: Ensure IAM roles have proper permissions

### Validation Steps

After deployment:
1. Test connectivity between hub and spokes
2. Verify internet access through NAT gateways
3. Check flow logs are being generated
4. Validate security group rules are working

## Contributing

When modifying this module:
1. Maintain security-first design principles
2. Test with multiple spoke VPC configurations
3. Verify Transit Gateway routing works correctly
4. Update documentation for any new features