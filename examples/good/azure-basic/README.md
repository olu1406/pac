# Azure Basic Secure Configuration

This example demonstrates a basic Azure setup that passes all security controls. It includes secure configurations for common Azure resources following security best practices.

## Security Features

### Identity & Access Management
- **RBAC Policies**: Role-based access control with least privilege
- **No Wildcard Permissions**: Custom roles use specific actions
- **Limited Scope**: Role assignments scoped to resource groups
- **Service Principal Security**: Application passwords with expiration dates

### Networking
- **Network Security Groups**: Restricted SSH and RDP access
- **No Public Access**: NSG rules deny unrestricted inbound access
- **Controlled Ports**: High-risk ports are properly secured
- **Network Segmentation**: Proper subnet isolation

### Data Protection
- **Storage Encryption**: HTTPS-only storage accounts
- **Private Access**: No public blob access allowed
- **Container Security**: Private container access types
- **TLS 1.2**: Minimum TLS version enforced
- **Soft Delete**: Blob soft delete enabled for data protection

### Monitoring & Compliance
- **Activity Logs**: Centralized logging configuration
- **Security Center**: Defender for Cloud integration
- **Network Monitoring**: NSG flow logs enabled
- **Resource Tagging**: Consistent tagging for governance

## Resources Created

- Resource Group with proper naming and tagging
- Virtual Network with secure subnet configuration
- Network Security Groups with restrictive rules
- Storage Account with full security configuration
- Key Vault for secrets management
- Log Analytics Workspace for monitoring
- Service Principal with limited permissions
- RBAC role assignments with appropriate scope

## Usage

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="terraform.tfvars"

# Apply the configuration
terraform apply -var-file="terraform.tfvars"

# Test with policy validation
TERRAFORM_DIR=examples/good/azure-basic make scan
```

## Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and customize:

- `environment`: Environment name (dev/test/prod)
- `project_name`: Project identifier for resource naming
- `location`: Azure region for resource deployment
- `allowed_ssh_cidr`: CIDR block allowed for SSH access
- `vnet_cidr`: Virtual Network CIDR block

## Security Compliance

This configuration satisfies the following security controls:

- **AZ-IAM-001**: No wildcard permissions in custom RBAC roles
- **AZ-IAM-002**: No Owner permissions at subscription scope
- **AZ-IAM-003**: Service principal credentials have expiration dates
- **AZ-IAM-005**: Privileged role assignments documented for MFA requirements
- **AZ-NET-001**: No SSH access from any source (*)
- **AZ-NET-002**: No RDP access from any source (*)
- **AZ-NET-003**: No unrestricted inbound access
- **AZ-NET-004**: Custom NSG rules defined
- **AZ-NET-005**: High-risk ports properly secured
- **AZ-DATA-001**: HTTPS-only storage accounts
- **AZ-DATA-002**: No public blob access
- **AZ-DATA-003**: Private container access
- **AZ-DATA-005**: TLS 1.2 minimum version
- **AZ-DATA-006**: Blob soft delete enabled

All controls are validated through automated policy checks.