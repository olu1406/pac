# AWS Environment Configurations

This directory contains environment-specific variable files for deploying AWS landing zone modules across different environments (dev, test, prod). Each environment is optimized for its specific use case while maintaining security best practices.

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
terraform plan -var-file="modules/aws/environments/dev.tfvars"
terraform apply -var-file="modules/aws/environments/dev.tfvars"

# Test environment
terraform plan -var-file="modules/aws/environments/test.tfvars"
terraform apply -var-file="modules/aws/environments/test.tfvars"

# Production environment
terraform plan -var-file="modules/aws/environments/prod.tfvars"
terraform apply -var-file="modules/aws/environments/prod.tfvars"
```

### Using with Terraform Workspaces

```bash
# Create and select workspace
terraform workspace new dev
terraform workspace select dev

# Deploy with environment file
terraform apply -var-file="modules/aws/environments/dev.tfvars"
```

### Using with CI/CD

Example GitHub Actions workflow:

```yaml
name: Deploy AWS Landing Zone
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
    
    - name: Terraform Init
      run: terraform init
    
    - name: Terraform Plan
      run: terraform plan -var-file="modules/aws/environments/${{ matrix.environment }}.tfvars"
    
    - name: Terraform Apply
      if: matrix.environment != 'prod' || github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve -var-file="modules/aws/environments/${{ matrix.environment }}.tfvars"
```

## Environment Details

### Development Environment (dev.tfvars)

**Purpose**: Fast iteration and development testing

**Key Features**:
- Cost-optimized configuration
- Reduced availability zones (2 instead of 3)
- Disabled NAT gateways for cost savings
- Shorter log retention (30 days)
- Permissive management access
- CloudWatch logs instead of S3 for small volumes

**Security Trade-offs**:
- More permissive network access for development ease
- Reduced monitoring and logging retention
- No break glass roles (not needed for dev)

**Cost Savings**:
- ~70% cost reduction compared to production
- No NAT gateway charges (~$45/month savings per AZ)
- Shorter log retention reduces storage costs

### Test Environment (test.tfvars)

**Purpose**: Production-like testing and QA validation

**Key Features**:
- Production-like security configuration
- Moderate cost optimization
- Full networking features for testing
- Break glass roles for testing emergency procedures
- 90-day log retention

**Security Features**:
- Restricted management access
- Full Transit Gateway connectivity
- VPC Flow Logs enabled
- Security group baselines

**Use Cases**:
- Integration testing
- Security testing
- Performance testing
- Disaster recovery testing

### Production Environment (prod.tfvars)

**Purpose**: Production workloads with full security and compliance

**Key Features**:
- Maximum security configuration
- Full compliance features
- High availability (3 AZs)
- Long-term log retention (7 years)
- Comprehensive monitoring

**Security Features**:
- Break glass emergency access
- GuardDuty with S3 export
- Encrypted storage for all logs
- Restricted management access
- Service control policies

**Compliance**:
- SOC 2 Type II ready
- 7-year log retention for regulatory requirements
- Comprehensive audit trails
- Data classification tags

## Customization Guide

### Before Deployment

1. **Update Account IDs**: Replace placeholder account IDs with your actual AWS account IDs
2. **Change External IDs**: Use secure random values for external IDs
3. **Update CIDR Blocks**: Ensure CIDR blocks don't conflict with existing networks
4. **Configure Management Access**: Update management_cidrs with your actual network ranges
5. **Set Break Glass Users**: Update break glass user ARNs for production

### Required Changes

```bash
# Search for placeholder values that need updating
grep -r "123456789012" modules/aws/environments/
grep -r "change-me" modules/aws/environments/
grep -r "203.0.113" modules/aws/environments/
```

### Security Considerations

1. **External IDs**: Use cryptographically secure random values
2. **Management CIDRs**: Restrict to known management networks
3. **Break Glass Users**: Limit to essential personnel only
4. **Account IDs**: Verify account IDs are correct for cross-account access

### Cost Optimization

#### Development Optimizations
- Set `enable_nat_gateway = false`
- Use `flow_logs_destination = "cloudwatch"`
- Reduce `availability_zone_count = 2`
- Shorter retention periods

#### Production Considerations
- Enable all security features
- Use S3 for flow logs (better for large volumes)
- Longer retention for compliance
- Multiple AZs for high availability

## Environment-Specific Examples

### Custom Development Setup

```hcl
# Custom dev configuration for specific team
organization_name = "team-alpha-dev"
environment      = "dev"

# Minimal spoke VPCs for specific use case
spoke_vpcs = [
  {
    name         = "frontend-dev"
    cidr_block   = "10.11.0.0/16"
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
organization_name = "mycompany-us-west-2"
environment      = "prod"

# Region-specific CIDR blocks
hub_vpc_cidr = "10.100.0.0/16"

spoke_vpcs = [
  {
    name       = "web-us-west-2"
    cidr_block = "10.101.0.0/16"
  }
]
```

## Validation

### Pre-Deployment Checklist

- [ ] Updated all placeholder account IDs
- [ ] Changed default external IDs to secure values
- [ ] Configured management CIDR blocks
- [ ] Set appropriate break glass users for production
- [ ] Verified CIDR blocks don't conflict
- [ ] Reviewed cost implications
- [ ] Confirmed compliance requirements

### Post-Deployment Validation

```bash
# Verify resources were created
terraform show | grep -E "(vpc|security_group|cloudtrail)"

# Check security group rules
aws ec2 describe-security-groups --group-names "*default*"

# Verify flow logs are working
aws logs describe-log-groups --log-group-name-prefix "/aws/vpc"

# Check GuardDuty status (production)
aws guardduty list-detectors
```

## Troubleshooting

### Common Issues

1. **CIDR Conflicts**: Ensure hub and spoke CIDRs don't overlap
2. **Account ID Errors**: Verify account IDs are correct and accessible
3. **Permission Errors**: Ensure Terraform has necessary AWS permissions
4. **Resource Limits**: Check AWS service limits for your account

### Support

For issues with environment configurations:
1. Check AWS CloudTrail for API errors
2. Verify IAM permissions for Terraform execution
3. Review Terraform state for resource conflicts
4. Consult AWS documentation for service-specific limits

## Contributing

When adding new environment configurations:
1. Follow the naming convention: `{environment}.tfvars`
2. Include comprehensive documentation
3. Test with actual deployments
4. Update this README with new environment details