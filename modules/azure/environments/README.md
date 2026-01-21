# Azure Environment Configurations

This directory contains environment-specific variable files for deploying Azure landing zone modules across different environments (dev, test, prod). Each environment is optimized for its specific use case while maintaining security best practices.

## Environment Overview

| Environment | Purpose | Security Level | Cost Optimization | Compliance |
|-------------|---------|----------------|-------------------|------------|
| **dev** | Development and testing | Moderate | High | Basic |
| **test** | Integration testing and QA | High | Moderate | Intermediate |
| **prod** | Production workloads | Maximum | Low | Full |

## Usage

### Using Environment Files

Deploy using Terraform with environment-specific variable files:

```bash
# Development environment
terraform plan -var-file="modules/azure/environments/dev.tfvars"
terraform apply -var-file="modules/azure/environments/dev.tfvars"

# Test environment
terraform plan -var-file="modules/azure/environments/test.tfvars"
terraform apply -var-file="modules/azure/environments/test.tfvars"

# Production environment
terraform plan -var-file="modules/azure/environments/prod.tfvars"
terraform apply -var-file="modules/azure/environments/prod.tfvars"
```

### Using with Terraform Workspaces

```bash
# Create and select workspace
terraform workspace new dev
terraform workspace select dev

# Deploy with environment file
terraform apply -var-file="modules/azure/environments/dev.tfvars"
```

### Using with CI/CD

Example GitHub Actions workflow:

```yaml
name: Deploy Azure Landing Zone
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, test, prod]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Terraform Init
      run: terraform init
    
    - name: Terraform Plan
      run: terraform plan -var-file="modules/azure/environments/${{ matrix.environment }}.tfvars"
    
    - name: Terraform Apply
      if: matrix.environment != 'prod' || github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve -var-file="modules/azure/environments/${{ matrix.environment }}.tfvars"
```

## Environment Details

### Development Environment (dev.tfvars)

**Purpose**: Fast iteration and development testing

**Key Features**:
- Cost-optimized configuration
- Disabled premium services (Defender for Cloud, Azure Firewall, Bastion)
- Shorter log retention (30 days)
- Permissive management access
- Simplified RBAC with built-in roles only

**Security Trade-offs**:
- More permissive network access for development ease
- Reduced monitoring and logging retention
- No break glass roles (not needed for dev)
- Disabled advanced security services

**Cost Savings**:
- ~75% cost reduction compared to production
- No Azure Firewall charges (~$1,200/month savings)
- No Azure Bastion charges (~$140/month savings)
- No Defender for Cloud charges (~$15/server/month savings)
- Shorter log retention reduces storage costs

### Test Environment (test.tfvars)

**Purpose**: Production-like testing and QA validation

**Key Features**:
- Production-like security configuration
- Moderate cost optimization
- Full RBAC features for testing
- Break glass roles for testing emergency procedures
- 90-day log retention

**Security Features**:
- Restricted management access
- Full VNet peering connectivity
- NSG Flow Logs with Traffic Analytics
- Custom RBAC roles
- Defender for Cloud enabled

**Use Cases**:
- Integration testing
- Security testing
- Performance testing
- Disaster recovery testing
- RBAC and policy testing

### Production Environment (prod.tfvars)

**Purpose**: Production workloads with full security and compliance

**Key Features**:
- Maximum security configuration
- Full compliance features
- Premium service tiers (VPN Gateway VpnGw2, Firewall Premium)
- Long-term log retention (7 years)
- Comprehensive monitoring

**Security Features**:
- Break glass emergency access
- Defender for Cloud on all subscriptions
- Azure Firewall Premium with advanced threat protection
- Azure Bastion for secure remote access
- Custom RBAC roles with least privilege
- Comprehensive audit trails

**Compliance**:
- SOC 2 Type II ready
- 7-year log retention for regulatory requirements
- Data classification tags
- Comprehensive security monitoring

## Customization Guide

### Before Deployment

1. **Update Subscription IDs**: Replace placeholder subscription IDs with your actual Azure subscription IDs
2. **Update Azure AD Group IDs**: Replace placeholder group object IDs with your actual Azure AD groups
3. **Update User IDs**: Replace placeholder user object IDs for break glass access
4. **Change CIDR Blocks**: Ensure CIDR blocks don't conflict with existing networks
5. **Configure Management Access**: Update management_cidrs with your actual network ranges
6. **Set Security Contacts**: Update security contact email and phone numbers

### Required Changes

```bash
# Search for placeholder values that need updating
grep -r "12345678-1234-1234-1234-123456789012" modules/azure/environments/
grep -r "mycompany.com" modules/azure/environments/
grep -r "203.0.113" modules/azure/environments/
```

### Security Considerations

1. **Subscription IDs**: Verify subscription IDs are correct and accessible
2. **Azure AD Groups**: Ensure groups exist and have appropriate members
3. **Management CIDRs**: Restrict to known management networks
4. **Break Glass Users**: Limit to essential personnel only
5. **Security Contacts**: Use monitored email addresses and phone numbers

### Cost Optimization

#### Development Optimizations
- Set `enable_defender_for_cloud = false`
- Set `enable_azure_firewall = false`
- Set `enable_azure_bastion = false`
- Set `enable_vpn_gateway = false`
- Use shorter retention periods
- Disable Traffic Analytics

#### Production Considerations
- Enable all security features
- Use Premium SKUs for enhanced security
- Longer retention for compliance
- Enable comprehensive monitoring
- Use higher VPN Gateway SKUs for performance

## Environment-Specific Examples

### Custom Development Setup

```hcl
# Custom dev configuration for specific team
organization_name = "team-alpha-dev"
environment      = "dev"

# Minimal spoke VNets for specific use case
spoke_vnets = [
  {
    name          = "frontend-dev"
    cidr_block    = "10.11.0.0/16"
    allowed_ports = [3000, 8080]
  }
]

# Team-specific tags
tags = {
  Environment = "dev"
  Team        = "alpha"
  Project     = "web-app"
}
```

### Multi-Region Production

```hcl
# Production configuration for specific region
organization_name = "mycompany-west-us-2"
environment      = "prod"
location         = "West US 2"

# Region-specific CIDR blocks
hub_vnet_cidr = "10.100.0.0/16"

spoke_vnets = [
  {
    name       = "web-west-us-2"
    cidr_block = "10.101.0.0/16"
  }
]
```

## Azure-Specific Configuration

### Management Groups

The landing zone uses Azure Management Groups for hierarchical organization:

```
Tenant Root Group
├── Root Management Group (mycompany)
│   ├── Platform Management Group
│   │   ├── Identity Subscription
│   │   ├── Connectivity Subscription
│   │   └── Management Subscription
│   ├── Landing Zones Management Group
│   │   ├── Corp Management Group
│   │   └── Online Management Group
│   ├── Sandbox Management Group
│   └── Decommissioned Management Group
```

### RBAC Roles

Custom roles created by the landing zone:

- **Security Reader**: Read-only access to security resources
- **Security Operator**: Operational access to security tools
- **Break Glass**: Emergency access for critical situations

### Azure Policy

Built-in and custom policies applied:

- **Security Baseline**: CIS Azure Foundations Benchmark
- **Networking**: Network security group rules and VNet configurations
- **Identity**: Azure AD and RBAC configurations
- **Data Protection**: Encryption and backup requirements

## Validation

### Pre-Deployment Checklist

- [ ] Updated all placeholder subscription IDs
- [ ] Updated Azure AD group object IDs
- [ ] Updated break glass user object IDs
- [ ] Configured management CIDR blocks
- [ ] Set appropriate security contacts
- [ ] Verified CIDR blocks don't conflict
- [ ] Reviewed cost implications
- [ ] Confirmed compliance requirements

### Post-Deployment Validation

```bash
# Verify management groups were created
az account management-group list --query "[].{Name:displayName,Id:name}"

# Check policy assignments
az policy assignment list --query "[].{Name:displayName,PolicyDefinitionId:policyDefinitionId}"

# Verify VNet configuration
az network vnet list --query "[].{Name:name,AddressSpace:addressSpace.addressPrefixes}"

# Check NSG rules
az network nsg list --query "[].{Name:name,ResourceGroup:resourceGroup}"

# Verify Defender for Cloud status
az security pricing list --query "value[].{Name:name,PricingTier:pricingTier}"
```

## Troubleshooting

### Common Issues

1. **Subscription Access**: Ensure you have Owner or Contributor access to target subscriptions
2. **Azure AD Permissions**: Verify permissions to read/assign Azure AD groups and users
3. **CIDR Conflicts**: Ensure VNet CIDRs don't overlap with existing networks
4. **Resource Limits**: Check Azure subscription limits and quotas
5. **Policy Conflicts**: Existing policies may conflict with landing zone policies

### Azure CLI Troubleshooting

```bash
# Check current subscription and permissions
az account show
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Verify Azure AD permissions
az ad signed-in-user show
az ad group list --query "[].{DisplayName:displayName,ObjectId:objectId}"

# Check resource provider registrations
az provider list --query "[?registrationState=='NotRegistered'].{Namespace:namespace}"

# Register required providers
az provider register --namespace Microsoft.Security
az provider register --namespace Microsoft.PolicyInsights
```

### Support

For issues with Azure environment configurations:
1. Check Azure Activity Log for deployment errors
2. Verify Azure RBAC permissions for Terraform execution
3. Review Terraform state for resource conflicts
4. Consult Azure documentation for service-specific limits
5. Use Azure Resource Health for service status

## Contributing

When adding new environment configurations:
1. Follow the naming convention: `{environment}.tfvars`
2. Include comprehensive documentation
3. Test with actual Azure deployments
4. Update this README with new environment details
5. Ensure compliance with Azure security best practices

## Security Best Practices

### Network Security
- Use Network Security Groups (NSGs) with least privilege rules
- Enable NSG Flow Logs for network monitoring
- Implement hub-spoke topology for network segmentation
- Use Azure Firewall for centralized network security

### Identity and Access
- Implement Azure AD Privileged Identity Management (PIM)
- Use custom RBAC roles with least privilege
- Enable break glass accounts for emergency access
- Regular access reviews and role assignments

### Data Protection
- Enable encryption at rest for all storage accounts
- Use Azure Key Vault for secrets management
- Implement backup and disaster recovery
- Data classification and handling procedures

### Monitoring and Compliance
- Enable Microsoft Defender for Cloud
- Configure Log Analytics for centralized logging
- Implement Azure Policy for compliance enforcement
- Regular security assessments and penetration testing