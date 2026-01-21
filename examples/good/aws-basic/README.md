# AWS Basic Secure Configuration

This example demonstrates a basic AWS setup that passes all security controls. It includes secure configurations for common AWS resources following security best practices.

## Security Features

### Identity & Access Management (IAM)
- **Least Privilege**: IAM policies use specific actions instead of wildcards
- **Managed Policies**: Uses AWS managed policies and custom managed policies instead of inline policies
- **Specific Principals**: IAM role trust policies specify explicit principals
- **No Root Keys**: No access keys created for root user

### Networking
- **Restricted SSH/RDP**: Security groups restrict SSH (port 22) and RDP (port 3389) to specific IP ranges
- **Default Security Group**: Default security group has no rules configured
- **Controlled Egress**: Outbound traffic is restricted to specific ports and destinations
- **VPC Flow Logs**: Network traffic logging enabled for security monitoring

### Data Protection
- **S3 Encryption**: All S3 buckets have server-side encryption enabled
- **Public Access Blocked**: S3 buckets block all public access
- **Versioning**: S3 buckets have versioning enabled for data protection
- **Access Logging**: S3 access logging enabled for audit trails

### Logging & Monitoring
- **CloudTrail**: API call logging enabled across all regions
- **Config**: Configuration compliance monitoring enabled
- **GuardDuty**: Threat detection service enabled

## Resources Created

- VPC with private and public subnets
- Internet Gateway and NAT Gateway
- Security Groups with restricted access
- S3 bucket with full security configuration
- IAM role and policy for EC2 instances
- CloudTrail for audit logging
- VPC Flow Logs for network monitoring

## Usage

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="terraform.tfvars"

# Apply the configuration
terraform apply -var-file="terraform.tfvars"

# Test with policy validation
TERRAFORM_DIR=examples/good/aws-basic make scan
```

## Variables

Copy `terraform.tfvars.example` to `terraform.tfvars` and customize:

- `environment`: Environment name (dev/test/prod)
- `project_name`: Project identifier for resource naming
- `allowed_ssh_cidr`: CIDR block allowed for SSH access
- `vpc_cidr`: VPC CIDR block

## Security Compliance

This configuration satisfies the following security controls:

- **IAM-001**: No wildcard actions on all resources
- **IAM-002**: No inline policies on users
- **IAM-003**: Specific principals in trust policies
- **IAM-004**: No root access keys
- **NET-001**: No public SSH access from 0.0.0.0/0
- **NET-002**: No public RDP access from 0.0.0.0/0
- **NET-003**: Default security group has no rules
- **NET-004**: Restricted outbound traffic
- **DATA-001**: S3 server-side encryption enabled
- **DATA-002**: S3 public access blocked
- **DATA-003**: S3 versioning enabled
- **DATA-004**: S3 access logging enabled

All controls are validated through automated policy checks.