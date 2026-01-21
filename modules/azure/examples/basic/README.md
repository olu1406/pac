# Basic Azure Landing Zone Example

This example demonstrates a basic Azure landing zone setup using the Azure management groups and networking modules. It creates a simple hub-spoke network topology with security baselines and monitoring.

## Architecture

This example creates:
- Management group hierarchy (Root → Security/Workloads)
- Hub VNet with Azure Bastion for secure access
- Single spoke VNet for applications
- Network Security Groups with baseline rules
- NSG Flow Logs for network monitoring
- Microsoft Defender for Cloud (basic configuration)

## Usage

### Using Environment Files (Recommended)

The easiest way to use this example is with the pre-configured environment files:

```bash
# Development environment
terraform init
terraform plan -var-file="../environments/dev.tfvars"
terraform apply -var-file="../environments/dev.tfvars"

# Test environment
terraform plan -var-file="../environments/test.tfvars"
terraform apply -var-file="../environments/test.tfvars"
```

### Manual Configuration

1. **Configure Azure Provider Authentication**
   ```bash
   # Using Azure CLI
   az login
   
   # Or set environment variables
   export ARM_CLIENT_ID="your-client-id"
   export ARM_CLIENT_SECRET="your-client-secret"
   export ARM_SUBSCRIPTION_ID="your-subscription-id"
   export ARM_TENANT_ID="your-tenant-id"
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Review and Customize Variables**
   ```bash
   # Copy and customize the example tfvars
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Plan and Apply**
   ```bash
   terraform plan
   terraform apply
   ```

## Environment Files

This example works with the environment configuration files in `../environments/`:

- **dev.tfvars**: Cost-optimized development environment
- **test.tfvars**: Production-like testing environment  
- **prod.tfvars**: Full production configuration

### Customizing Environment Files

Before using the environment files, update the following values:

```bash
# Required changes in environment files
organization_name = "your-company-name"
security_subscription_ids = ["your-security-subscription-id"]
workload_subscription_ids = ["your-workload-subscription-id"]
security_contact_email = "security@yourcompany.com"
management_cidrs = ["your-office-network-cidr"]
```

## Configuration

### Required Variables

```hcl
organization_name = "mycompany"
environment      = "dev"
location         = "East US"

# Add your subscription IDs
security_subscription_ids  = ["your-security-subscription-id"]
workload_subscription_ids  = ["your-workload-subscription-id"]

# Security contact
security_contact_email = "security@mycompany.com"

# Management access
management_cidrs = ["203.0.113.0/24"]  # Your office network
```

### Optional Customizations

```hcl
# Custom spoke VNets
spoke_vnets = [
  {
    name          = "web"
    cidr_block    = "10.1.0.0/16"
    allowed_ports = [80, 443]
  },
  {
    name          = "api"
    cidr_block    = "10.2.0.0/16"
    allowed_ports = [8080, 9090]
  }
]

# Custom tags
tags = {
  Environment = "development"
  Owner       = "platform-team"
  Project     = "landing-zone"
}
```

## Example terraform.tfvars

```hcl
# Basic configuration
organization_name = "contoso"
environment      = "dev"
location         = "East US"

# Subscription assignments
security_subscription_ids  = ["12345678-1234-1234-1234-123456789012"]
workload_subscription_ids  = ["87654321-4321-4321-4321-210987654321"]

# Security configuration
security_contact_email = "security@contoso.com"
security_reader_groups = ["security-readers-group-id"]

# Network configuration
name_prefix         = "contoso-dev"
resource_group_name = "rg-networking-dev"
hub_vnet_cidr      = "10.0.0.0/16"

spoke_vnets = [
  {
    name          = "app"
    cidr_block    = "10.1.0.0/16"
    allowed_ports = [80, 443, 8080]
  }
]

# Management access (replace with your network)
management_cidrs = ["203.0.113.0/24"]

# Tags
tags = {
  Environment = "dev"
  Owner       = "platform-team"
  Purpose     = "landing-zone-example"
}
```

## Outputs

After successful deployment, you'll get:

- **Management Group IDs**: For policy assignments and RBAC
- **VNet Information**: Hub and spoke VNet IDs and names
- **Security Resources**: Bastion host and flow logs storage account
- **Monitoring**: Log Analytics workspace for security logging

## Environment Comparison

| Feature | Dev | Test | Prod |
|---------|-----|------|------|
| Defender for Cloud | ❌ | ✅ | ✅ |
| Azure Bastion | ❌ | ✅ | ✅ |
| VPN Gateway | ❌ | ❌ | ✅ |
| Azure Firewall | ❌ | ❌ | ✅ |
| Log Retention | 30 days | 90 days | 7 years |
| Management Access | Open | Restricted | Highly Restricted |

## Next Steps

1. **Add Workloads**: Deploy applications to the spoke VNets
2. **Configure Policies**: Add custom Azure Policy definitions
3. **Set up Monitoring**: Configure alerts and dashboards
4. **Implement RBAC**: Assign users and groups to custom roles

## Clean Up

To destroy the resources:

```bash
terraform destroy -var-file="../environments/dev.tfvars"
```

**Note**: Some resources like management groups may have dependencies that prevent immediate deletion. You may need to remove policy assignments and role assignments manually before destroying.

## Security Considerations

This basic example includes:
- ✅ Network segmentation with hub-spoke topology
- ✅ Default-deny NSG rules
- ✅ Secure remote access via Azure Bastion (test/prod)
- ✅ Network traffic logging with NSG Flow Logs
- ✅ Microsoft Defender for Cloud baseline (test/prod)

For production use, consider:
- Adding Azure Firewall for centralized security
- Implementing VPN Gateway for hybrid connectivity
- Configuring custom Azure Policy definitions
- Setting up advanced monitoring and alerting
- Implementing proper RBAC with Azure AD groups

## Troubleshooting

### Common Issues

1. **Insufficient Permissions**
   - Ensure your account has Owner or Contributor role on subscriptions
   - Management group creation requires special permissions

2. **Resource Name Conflicts**
   - Storage account names must be globally unique
   - Adjust the `name_prefix` variable if needed

3. **Subscription Limits**
   - Check Azure subscription limits for VNets and NSGs
   - Some regions may have capacity constraints

4. **Environment File Issues**
   - Ensure subscription IDs in environment files are correct
   - Verify Azure AD group IDs exist and are accessible

### Getting Help

- Check the [Azure Provider Documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- Review the [module documentation](../../README.md)
- Review the [environment configuration guide](../environments/README.md)
- Open an issue in the repository for bugs or feature requests