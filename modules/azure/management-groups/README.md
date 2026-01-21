# Azure Management Group and Subscription Baseline Module

This Terraform module creates a secure Azure management group hierarchy with RBAC baseline, Azure Policy assignments, and Microsoft Defender for Cloud configuration. It implements security best practices and provides a foundation for enterprise Azure deployments.

## Features

- **Management Group Hierarchy**: Creates a structured hierarchy (Root → Security/Workloads/Platform/Sandbox)
- **Azure Policy Baseline**: Implements security baseline policies with framework mappings
- **RBAC Integration**: Custom roles and assignments for security teams
- **Defender for Cloud**: Enables Microsoft Defender across multiple subscription tiers
- **PIM Integration Patterns**: Supports Privileged Identity Management workflows
- **Compliance Framework Support**: Maps to NIST 800-53, ISO 27001, and CIS benchmarks

## Architecture

```
Root Management Group
├── Security Management Group
├── Workloads Management Group  
├── Platform Management Group
└── Sandbox Management Group
```

## Usage

### Basic Usage

```hcl
module "azure_management_groups" {
  source = "./modules/azure/management-groups"

  organization_name = "contoso"
  environment      = "prod"
  location         = "East US"

  # Management group configuration
  create_management_group_hierarchy = true
  security_subscription_ids         = ["sub-12345678-1234-1234-1234-123456789012"]
  workload_subscription_ids         = ["sub-87654321-4321-4321-4321-210987654321"]

  # Security configuration
  enable_defender_for_cloud = true
  security_contact_email    = "security@contoso.com"
  
  # RBAC configuration
  security_reader_groups   = ["group-id-1", "group-id-2"]
  security_operator_groups = ["group-id-3"]

  tags = {
    Environment = "Production"
    Owner       = "Platform Team"
  }
}
```

### Advanced Usage with Custom Policies

```hcl
module "azure_management_groups" {
  source = "./modules/azure/management-groups"

  organization_name = "contoso"
  environment      = "prod"

  # Use existing management group hierarchy
  create_management_group_hierarchy    = false
  existing_root_management_group_id    = "/providers/Microsoft.Management/managementGroups/contoso-root"
  existing_security_management_group_id = "/providers/Microsoft.Management/managementGroups/contoso-security"

  # Enhanced security configuration
  create_security_policies = true
  create_custom_roles      = true
  enable_break_glass_role  = true
  break_glass_user_ids     = ["user-id-1", "user-id-2"]

  # Defender for Cloud configuration
  enable_defender_for_cloud    = true
  defender_subscription_ids    = [
    "sub-12345678-1234-1234-1234-123456789012",
    "sub-87654321-4321-4321-4321-210987654321"
  ]
  security_contact_email       = "security@contoso.com"
  security_contact_phone       = "+1-555-123-4567"
  
  # Log Analytics configuration
  create_log_analytics_workspace = true
  security_resource_group_name   = "rg-security-prod"
  log_retention_days            = 180

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
| azuread | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | ~> 3.0 |
| azuread | ~> 2.0 |

## Resources Created

### Management Groups
- Root management group (optional)
- Security management group
- Workloads management group
- Platform management group
- Sandbox management group

### Azure Policies
- Security baseline policy initiative
- Deny high-risk actions policy
- Policy assignments at management group level

### RBAC
- Custom security reader role
- Custom security operator role
- Break glass emergency access role (optional)
- Role assignments for security groups

### Microsoft Defender for Cloud
- Defender for Servers (P2)
- Defender for Storage (DefenderForStorageV2)
- Defender for SQL
- Defender for Containers
- Defender for Key Vault
- Security contact configuration
- Auto-provisioning settings

### Logging
- Log Analytics workspace for security logs
- Security Center workspace configuration

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| organization_name | Name of the organization | `string` | n/a | yes |
| environment | Environment name (dev, test, prod) | `string` | `"prod"` | no |
| location | Azure region for resources | `string` | `"East US"` | no |
| create_management_group_hierarchy | Whether to create management group hierarchy | `bool` | `true` | no |
| security_subscription_ids | List of subscription IDs for security management group | `list(string)` | `[]` | no |
| enable_defender_for_cloud | Whether to enable Microsoft Defender for Cloud | `bool` | `true` | no |
| security_contact_email | Email address for security contact notifications | `string` | `""` | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| root_management_group_id | The root management group ID |
| security_management_group_id | The security management group ID |
| security_baseline_policy_set_id | ID of the security baseline policy set |
| log_analytics_workspace_id | ID of the Log Analytics workspace |

See [outputs.tf](./outputs.tf) for complete list of outputs.

## Security Considerations

### Policy Enforcement
- Denies high-risk actions like unrestricted network access
- Enforces security baseline across all subscriptions
- Audits compliance with security frameworks

### RBAC Best Practices
- Implements least-privilege access principles
- Separates security reader and operator roles
- Provides emergency break glass access with audit trail

### Defender for Cloud
- Enables advanced threat protection across multiple services
- Configures security contact for incident notifications
- Integrates with Log Analytics for centralized logging

### Compliance Framework Mapping
- Maps policies to NIST 800-53 controls
- Supports ISO 27001 requirements
- Implements CIS Azure Foundations Benchmark controls

## Examples

See the [examples](../examples/) directory for complete usage examples:
- [Basic management group setup](../examples/basic/)
- [Advanced enterprise configuration](../examples/advanced/)

## Contributing

Please read [CONTRIBUTING.md](../../../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This module is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.