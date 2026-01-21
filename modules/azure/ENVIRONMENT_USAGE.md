# Azure Environment Configuration Usage Guide

This guide explains how to use the Azure landing zone modules with environment-specific configurations for consistent, secure deployments across development, test, and production environments.

## Overview

The Azure environment configuration system provides:
- **Pre-configured environments**: dev, test, and prod with appropriate security and cost settings
- **Consistent deployment**: Same modules, different configurations per environment
- **Security by default**: Each environment includes appropriate security controls
- **Cost optimization**: Development environments optimized for cost, production for security
- **Easy customization**: Simple variable files that can be modified for your organization

## Quick Start

### 1. Choose Your Deployment Method

#### Option A: Use Example Configurations (Recommended for new users)

```bash
cd modules/azure/examples/basic
terraform init
terraform plan -var-file="../environments/dev.tfvars"
terraform apply -var-file="../environments/dev.tfvars"
```

#### Option B: Use Modules Directly

```bash
# Create your own main.tf that calls the modules
# Use environment files for variable values
terraform init
terraform plan -var-file="modules/azure/environments/prod.tfvars"
terraform apply -var-file="modules/azure/environments/prod.tfvars"
```

### 2. Customize Environment Files

Before deployment, update the environment files with your organization's values:

```bash
# Edit the environment file for your target environment
vim modules/azure/environments/prod.tfvars

# Required changes:
# - organization_name
# - subscription IDs
# - Azure AD group IDs
# - security contact information
# - management network CIDRs
```

## Environment Configurations

### Development Environment (dev.tfvars)

**Purpose**: Fast development iteration with cost optimization

**Key Characteristics**:
- Minimal security services to reduce costs
- Permissive network access for development ease
- Shorter log retention periods
- Simplified RBAC configuration

**Cost Savings**:
- ~75% cost reduction vs production
- Disabled: Azure Firewall, Bastion, Defender for Cloud, VPN Gateway
- 30-day log retention vs 7-year production retention

**Security Trade-offs**:
- Open management access (0.0.0.0/0) - **DEV ONLY**
- No break glass roles
- Basic monitoring and logging

**Best For**:
- Individual developer environments
- Feature development and testing
- Proof of concepts
- Training and learning

### Test Environment (test.tfvars)

**Purpose**: Production-like testing with moderate cost optimization

**Key Characteristics**:
- Production-like security configuration
- Full RBAC and policy testing
- Comprehensive monitoring
- Restricted network access

**Features Enabled**:
- Microsoft Defender for Cloud
- Custom RBAC roles and break glass access
- Azure Bastion for secure access
- NSG Flow Logs with Traffic Analytics
- 90-day log retention

**Best For**:
- Integration testing
- Security and compliance testing
- Performance testing
- User acceptance testing
- Disaster recovery testing

### Production Environment (prod.tfvars)

**Purpose**: Full security, compliance, and enterprise features

**Key Characteristics**:
- Maximum security configuration
- Full compliance features
- Premium service tiers
- Long-term retention (7 years)
- Comprehensive monitoring

**Features Enabled**:
- Azure Firewall Premium with advanced threat protection
- VPN Gateway for hybrid connectivity
- Break glass emergency access with full audit trail
- Microsoft Defender for Cloud on all subscriptions
- Premium Key Vault with network restrictions
- Geo-redundant storage for security logs

**Best For**:
- Production workloads
- Regulated environments
- Enterprise deployments
- Compliance-critical systems

## Customization Guide

### Required Customizations

Before using any environment file, you must update these values:

#### 1. Organization Information
```hcl
organization_name = "your-company-name"  # Replace with your organization
environment      = "prod"               # Keep as-is for each environment
location         = "East US"            # Change to your preferred region
```

#### 2. Subscription IDs
```hcl
# Replace with your actual Azure subscription IDs
security_subscription_ids  = ["12345678-1234-1234-1234-123456789012"]
workload_subscription_ids  = ["87654321-4321-4321-4321-210987654321"]
platform_subscription_ids = ["11111111-2222-3333-4444-555555555555"]
```

#### 3. Azure AD Groups and Users
```hcl
# Replace with your actual Azure AD group object IDs
security_reader_groups   = ["aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"]
security_operator_groups = ["bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"]
break_glass_user_ids    = ["cccccccc-cccc-cccc-cccc-cccccccccccc"]
```

#### 4. Security Contacts
```hcl
security_contact_email = "security@yourcompany.com"
security_contact_phone = "+1-555-123-4567"
```

#### 5. Network Configuration
```hcl
# Replace with your actual management network CIDRs
management_cidrs = [
  "203.0.113.0/24",   # Your office network
  "198.51.100.0/24"   # Your VPN network
]

# Adjust VNet CIDRs if they conflict with existing networks
hub_vnet_cidr = "10.0.0.0/16"
```

### Optional Customizations

#### Custom Spoke VNets
```hcl
spoke_vnets = [
  {
    name          = "web-tier"
    cidr_block    = "10.1.0.0/16"
    allowed_ports = [80, 443]
  },
  {
    name          = "app-tier"
    cidr_block    = "10.2.0.0/16"
    allowed_ports = [8080, 9090]
  },
  {
    name          = "data-tier"
    cidr_block    = "10.3.0.0/16"
    # No allowed_ports for maximum security
  }
]
```

#### Custom Tags
```hcl
tags = {
  Environment        = "prod"
  Owner             = "platform-team"
  CostCenter        = "infrastructure"
  Project           = "landing-zone"
  ComplianceFramework = "SOC2"
  DataClassification = "confidential"
}
```

#### Service Toggles
```hcl
# Enable/disable services based on requirements
enable_azure_firewall      = true   # Set to false for cost savings
enable_vpn_gateway        = true   # Set to false if no hybrid connectivity needed
enable_azure_bastion      = true   # Set to false for cost savings (less secure)
enable_defender_for_cloud = true   # Set to false for cost savings (less secure)
```

## Deployment Workflows

### Single Environment Deployment

```bash
# Deploy to development
terraform init
terraform workspace new dev  # Optional: use workspaces
terraform plan -var-file="modules/azure/environments/dev.tfvars"
terraform apply -var-file="modules/azure/environments/dev.tfvars"
```

### Multi-Environment Deployment

```bash
# Deploy all environments
for env in dev test prod; do
  terraform workspace new $env
  terraform workspace select $env
  terraform plan -var-file="modules/azure/environments/${env}.tfvars"
  terraform apply -var-file="modules/azure/environments/${env}.tfvars"
done
```

### CI/CD Pipeline Integration

#### GitHub Actions Example

```yaml
name: Deploy Azure Landing Zone
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, test, prod]
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
    
    - name: Terraform Init
      run: terraform init
      working-directory: modules/azure/examples/basic
    
    - name: Terraform Plan
      run: terraform plan -var-file="../environments/${{ matrix.environment }}.tfvars"
      working-directory: modules/azure/examples/basic
    
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main' && matrix.environment != 'prod'
      run: terraform apply -auto-approve -var-file="../environments/${{ matrix.environment }}.tfvars"
      working-directory: modules/azure/examples/basic
    
    - name: Terraform Apply (Production)
      if: github.ref == 'refs/heads/main' && matrix.environment == 'prod'
      run: terraform apply -var-file="../environments/${{ matrix.environment }}.tfvars"
      working-directory: modules/azure/examples/basic
      # Remove -auto-approve for production to require manual approval
```

#### Azure DevOps Pipeline Example

```yaml
trigger:
  branches:
    include:
    - main

pool:
  vmImage: 'ubuntu-latest'

strategy:
  matrix:
    dev:
      environment: 'dev'
    test:
      environment: 'test'
    prod:
      environment: 'prod'

steps:
- task: AzureCLI@2
  displayName: 'Deploy $(environment) Environment'
  inputs:
    azureSubscription: 'Azure-Service-Connection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      cd modules/azure/examples/basic
      terraform init
      terraform plan -var-file="../environments/$(environment).tfvars"
      terraform apply -auto-approve -var-file="../environments/$(environment).tfvars"
```

## Validation and Testing

### Pre-Deployment Validation

```bash
# Validate Terraform configuration
terraform validate

# Check formatting
terraform fmt -check

# Security scan (if using tools like Checkov)
checkov -f modules/azure/environments/prod.tfvars

# Plan without applying
terraform plan -var-file="modules/azure/environments/prod.tfvars"
```

### Post-Deployment Validation

```bash
# Verify management groups
az account management-group list --query "[].{Name:displayName,Id:name}"

# Check policy assignments
az policy assignment list --query "[].{Name:displayName,Scope:scope}"

# Verify network configuration
az network vnet list --query "[].{Name:name,ResourceGroup:resourceGroup,AddressSpace:addressSpace.addressPrefixes}"

# Check security configuration
az security pricing list --query "value[].{Name:name,PricingTier:pricingTier}"
```

## Troubleshooting

### Common Issues

#### 1. Subscription Access Errors
```bash
# Check current subscription and permissions
az account show
az role assignment list --assignee $(az account show --query user.name -o tsv)
```

#### 2. Azure AD Permission Errors
```bash
# Check Azure AD permissions
az ad signed-in-user show
az ad group list --query "[].{DisplayName:displayName,ObjectId:objectId}"
```

#### 3. Resource Name Conflicts
```bash
# Storage account names must be globally unique
# Key Vault names must be globally unique
# Adjust name_prefix in environment files if needed
```

#### 4. Network CIDR Conflicts
```bash
# Check existing VNets in subscription
az network vnet list --query "[].{Name:name,AddressSpace:addressSpace.addressPrefixes}"

# Adjust CIDR blocks in environment files if conflicts exist
```

### Getting Help

1. **Azure CLI Issues**: Check Azure service health and CLI version
2. **Terraform Issues**: Review Terraform and provider versions
3. **Permission Issues**: Verify Azure RBAC and Azure AD permissions
4. **Network Issues**: Check NSG rules and routing tables
5. **Security Issues**: Review Azure Policy assignments and Defender for Cloud alerts

## Best Practices

### Security
- Always use restricted management CIDRs in production
- Enable all security services in production environments
- Use break glass accounts only for emergencies
- Regularly review and rotate access keys

### Cost Management
- Use development environments for cost optimization
- Monitor costs with Azure Cost Management
- Set up budget alerts for each environment
- Regularly review and clean up unused resources

### Operations
- Use consistent naming conventions across environments
- Tag all resources appropriately for cost allocation
- Implement proper backup and disaster recovery procedures
- Set up monitoring and alerting for critical resources

### Compliance
- Enable long-term log retention in production
- Implement proper data classification and handling
- Regular compliance assessments and audits
- Document all configuration changes and approvals

This environment configuration system provides a solid foundation for secure, compliant, and cost-effective Azure deployments across your organization's development lifecycle.