# Advanced Azure Landing Zone Example

This example demonstrates a comprehensive, production-ready Azure landing zone setup with full security features, compliance controls, and enterprise-grade architecture. It showcases the complete capabilities of the Azure management groups and networking modules.

## Architecture

This advanced example creates:

### Management Layer
- Complete management group hierarchy (Root → Security/Workloads/Platform/Sandbox)
- Custom Azure Policy definitions and assignments
- Custom RBAC roles for security operations
- Break glass emergency access roles
- Microsoft Defender for Cloud with all protection plans

### Network Layer
- Hub-spoke network topology with multiple spoke VNets
- Azure Firewall with policy-based rules
- VPN Gateway for hybrid connectivity
- Azure Bastion for secure remote access
- Comprehensive NSG Flow Logs with Traffic Analytics

### Security Layer
- Azure Key Vault with network restrictions
- Dedicated storage account for security logs
- Advanced threat protection across all services
- Compliance-ready logging and monitoring

## Features

- ✅ **Enterprise Management Groups**: Full hierarchy with policy enforcement
- ✅ **Advanced Networking**: Hub-spoke with firewall and VPN
- ✅ **Zero Trust Security**: Default-deny with least-privilege access
- ✅ **Compliance Ready**: SOC2, NIST 800-53, ISO 27001 mappings
- ✅ **Monitoring & Logging**: Comprehensive security event collection
- ✅ **Secrets Management**: Centralized Key Vault with network isolation
- ✅ **Emergency Access**: Break glass procedures with audit trail

## Prerequisites

1. **Azure Permissions**
   - Owner role on target subscriptions
   - Management Group Contributor at tenant root (for management group creation)
   - Azure AD permissions to create custom roles

2. **Azure AD Groups** (create these first)
   - Security readers group
   - Security operators group
   - Emergency access users

3. **Network Planning**
   - IP address ranges for hub and spoke VNets
   - On-premises network ranges (if using VPN)
   - Management network CIDRs

## Usage

### Using Environment Files (Recommended)

The easiest way to use this example is with the pre-configured environment files:

```bash
# Production environment (full features)
terraform init
terraform plan -var-file="../environments/prod.tfvars"
terraform apply -var-file="../environments/prod.tfvars"

# Test environment (production-like with cost optimization)
terraform plan -var-file="../environments/test.tfvars"
terraform apply -var-file="../environments/test.tfvars"
```

### Manual Configuration

### 1. Prepare Azure AD Groups

```bash
# Create security groups (replace with your naming convention)
az ad group create --display-name "Azure-Security-Readers" --mail-nickname "azure-security-readers"
az ad group create --display-name "Azure-Security-Operators" --mail-nickname "azure-security-operators"

# Get group object IDs
az ad group show --group "Azure-Security-Readers" --query objectId -o tsv
az ad group show --group "Azure-Security-Operators" --query objectId -o tsv
```

### 2. Using Environment Files

Before using the environment files, update the following values:

```bash
# Required changes in ../environments/prod.tfvars
organization_name = "your-company-name"
security_subscription_ids = ["your-security-subscription-id"]
workload_subscription_ids = ["your-workload-subscription-id"]
platform_subscription_ids = ["your-platform-subscription-id"]
security_reader_groups = ["your-security-readers-group-id"]
security_operator_groups = ["your-security-operators-group-id"]
break_glass_user_ids = ["your-break-glass-user-id"]
security_contact_email = "security@yourcompany.com"
management_cidrs = ["your-office-network-cidr"]
```

### 3. Deploy with Environment File

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="../environments/prod.tfvars"

# Apply (this will take 15-30 minutes)
terraform apply -var-file="../environments/prod.tfvars"
```

### Manual Configuration (Alternative)

### 1. Prepare Azure AD Groups

Create `terraform.tfvars` (if not using environment files):

```hcl
# Organization settings
organization_name = "contoso"
environment      = "prod"
location         = "East US"

# Subscription assignments (replace with your subscription IDs)
security_subscription_ids  = ["12345678-1234-1234-1234-123456789012"]
workload_subscription_ids  = ["87654321-4321-4321-4321-210987654321"]
platform_subscription_ids = ["11111111-2222-3333-4444-555555555555"]
sandbox_subscription_ids   = ["66666666-7777-8888-9999-000000000000"]

# Security configuration
create_security_policies = true
create_custom_roles      = true
enable_break_glass_role  = true

# RBAC assignments (replace with your Azure AD group/user IDs)
security_reader_groups = [
  "security-readers-group-object-id",
  "compliance-team-group-object-id"
]
security_operator_groups = [
  "security-operators-group-object-id",
  "incident-response-team-object-id"
]
break_glass_user_ids = [
  "emergency-admin-1-user-object-id",
  "emergency-admin-2-user-object-id"
]

# Defender for Cloud
enable_defender_for_cloud = true
defender_subscription_ids = [
  "87654321-4321-4321-4321-210987654321",
  "11111111-2222-3333-4444-555555555555"
]
security_contact_email = "security@contoso.com"
security_contact_phone = "+1-555-123-4567"

# Networking configuration
name_prefix         = "contoso"
resource_group_name = "rg-networking-prod"
hub_vnet_cidr      = "10.0.0.0/16"

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

# Connectivity
enable_hub_spoke_peering = true
enable_vpn_gateway      = true
vpn_gateway_sku        = "VpnGw2"
enable_azure_firewall  = true
firewall_sku_tier      = "Premium"
enable_azure_bastion   = true

# Security
management_cidrs = [
  "203.0.113.0/24",   # Corporate office
  "198.51.100.0/24"   # VPN users
]

# Monitoring
enable_nsg_flow_logs        = true
flow_logs_retention_days    = 365
flow_logs_analytics_enabled = true
log_retention_days         = 365

# Tags
tags = {
  Environment        = "prod"
  Owner             = "platform-team"
  Purpose           = "landing-zone"
  ComplianceFramework = "SOC2"
  DataClassification = "confidential"
}
```

### 3. Deploy (Manual Method)

```bash
# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="terraform.tfvars"

# Apply (this will take 15-30 minutes)
terraform apply -var-file="terraform.tfvars"
```

## Environment Comparison

| Feature | Test Environment | Production Environment |
|---------|------------------|------------------------|
| Management Groups | Simplified | Full Hierarchy |
| Azure Firewall | ❌ | ✅ Premium |
| VPN Gateway | ❌ | ✅ VpnGw2 |
| Break Glass Roles | ✅ (Testing) | ✅ (Production) |
| Log Retention | 90 days | 7 years |
| Defender for Cloud | ✅ | ✅ All Plans |
| Key Vault | ❌ | ✅ Premium |
| Management Access | Restricted | Highly Restricted |

## Post-Deployment Configuration

### 1. Configure VPN Connection

If you enabled the VPN Gateway, configure your on-premises connection:

```bash
# Get VPN Gateway public IP
terraform output vpn_gateway_public_ip

# Configure your on-premises VPN device with this IP
# Create local network gateway and connection in Azure
```

### 2. Configure Azure Firewall Rules

Customize firewall rules for your specific requirements:

```bash
# Access the firewall policy
terraform output azure_firewall_id

# Add custom application and network rules via Azure Portal or CLI
```

### 3. Set up Key Vault Secrets

```bash
# Get Key Vault name
terraform output key_vault_uri

# Add secrets (example)
az keyvault secret set --vault-name "your-kv-name" --name "database-password" --value "your-secure-password"
```

### 4. Configure Monitoring and Alerting

```bash
# Get Log Analytics workspace ID
terraform output log_analytics_workspace_id

# Set up custom alerts and dashboards in Azure Monitor
```

## Security Considerations

### Network Security
- **Zero Trust Architecture**: Default-deny NSG rules with explicit allow rules
- **Network Segmentation**: Hub-spoke topology with firewall inspection
- **Secure Remote Access**: Azure Bastion eliminates need for public IPs on VMs
- **Traffic Monitoring**: Comprehensive flow logs with analytics

### Identity and Access
- **Least Privilege**: Custom RBAC roles with minimal required permissions
- **Emergency Access**: Break glass roles with full audit trail
- **Policy Enforcement**: Azure Policy prevents configuration drift

### Data Protection
- **Encryption**: All data encrypted at rest and in transit
- **Key Management**: Centralized Key Vault with network isolation
- **Backup and Recovery**: Geo-redundant storage for critical data

### Monitoring and Compliance
- **Security Monitoring**: Microsoft Defender for Cloud across all services
- **Audit Logging**: Comprehensive activity and security logs
- **Compliance Frameworks**: Built-in mappings to SOC2, NIST, ISO standards

## Compliance Framework Mapping

This example implements controls for:

### NIST 800-53
- **AC-4**: Information Flow Enforcement (Network segmentation)
- **AU-6**: Audit Review, Analysis, and Reporting (Log Analytics)
- **SC-7**: Boundary Protection (Azure Firewall, NSGs)

### ISO 27001
- **A.13.1.1**: Network Controls (Network segmentation and monitoring)
- **A.12.4.1**: Event Logging (Comprehensive audit logging)
- **A.9.4.2**: Secure Log-on Procedures (Azure AD integration)

### SOC2 Type II
- **CC6.1**: Logical Access Controls (RBAC and Azure AD)
- **CC6.7**: Data Transmission (Encryption in transit)
- **CC7.2**: System Monitoring (Security monitoring and alerting)

## Cost Optimization

For non-production environments, consider:

```hcl
# Reduce costs by disabling premium features
enable_azure_firewall      = false  # Use NSGs only
firewall_sku_tier         = "Standard"  # If firewall needed
vpn_gateway_sku          = "VpnGw1"  # Lower performance tier
flow_logs_retention_days = 30  # Shorter retention
log_retention_days       = 90  # Shorter retention
```

## Troubleshooting

### Common Issues

1. **Management Group Permissions**
   ```bash
   # Check permissions
   az role assignment list --assignee your-user-id --scope /providers/Microsoft.Management/managementGroups/your-tenant-id
   ```

2. **Resource Name Conflicts**
   ```bash
   # Storage and Key Vault names must be globally unique
   # The template includes random suffixes to avoid conflicts
   ```

3. **Subscription Limits**
   ```bash
   # Check subscription limits
   az vm list-usage --location "East US"
   ```

### Getting Help

- Review the [troubleshooting guide](../../README.md#troubleshooting)
- Check Azure service health for regional issues
- Open support tickets for Azure-specific problems

## Clean Up

**Warning**: This will destroy all resources including data!

```bash
# Remove policy assignments first (if needed)
# Then destroy infrastructure
terraform destroy -var-file="../environments/prod.tfvars"
```

## Next Steps

1. **Application Deployment**: Deploy workloads to spoke VNets
2. **Custom Policies**: Add organization-specific Azure Policy definitions
3. **Monitoring**: Set up custom dashboards and alerts
4. **Automation**: Implement CI/CD pipelines for infrastructure updates
5. **Disaster Recovery**: Configure backup and recovery procedures

This advanced example provides a solid foundation for enterprise Azure deployments with security, compliance, and operational excellence built-in.