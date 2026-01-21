# Basic AWS Landing Zone Example

This example demonstrates a minimal secure AWS landing zone configuration using the organization and networking modules.

## What This Example Creates

- AWS Organization with basic security policies (optional)
- Hub VPC with secure networking baseline
- Single spoke VPC for applications
- CloudTrail for audit logging
- AWS Config for compliance monitoring
- GuardDuty for threat detection
- VPC Flow Logs for network monitoring

## Architecture

```
┌─────────────────────────────────────┐
│            Hub VPC                  │
│         (10.0.0.0/16)              │
│  ┌─────────────┐ ┌─────────────┐   │
│  │   Public    │ │   Public    │   │
│  │  Subnet     │ │  Subnet     │   │
│  │   (AZ-1)    │ │   (AZ-2)    │   │
│  └─────────────┘ └─────────────┘   │
│  ┌─────────────┐ ┌─────────────┐   │
│  │   Private   │ │   Private   │   │
│  │  Subnet     │ │  Subnet     │   │
│  │   (AZ-1)    │ │   (AZ-2)    │   │
│  └─────────────┘ └─────────────┘   │
└─────────────────────────────────────┘
                  │
        ┌─────────────────┐
        │ Transit Gateway │
        └─────────────────┘
                  │
        ┌─────────────────┐
        │   Spoke VPC     │
        │ (10.1.0.0/16)   │
        │   App Tier      │
        └─────────────────┘
```

## Usage

### Prerequisites

1. AWS CLI configured with appropriate permissions
2. Terraform >= 1.0 installed
3. AWS account with Organizations permissions (if creating organization)

### Deployment

1. **Clone and navigate to example**:
   ```bash
   cd modules/aws/examples/basic
   ```

2. **Initialize Terraform**:
   ```bash
   terraform init
   ```

3. **Review and customize variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Plan deployment**:
   ```bash
   terraform plan
   ```

5. **Deploy**:
   ```bash
   terraform apply
   ```

### Example terraform.tfvars

```hcl
aws_region        = "us-west-2"
organization_name = "mycompany"
environment      = "dev"
create_organization = false  # Set to true if creating new organization

tags = {
  Owner       = "platform-team"
  Environment = "dev"
  Project     = "landing-zone"
}
```

## Customization

### Adding More Spoke VPCs

```hcl
module "networking" {
  source = "../../networking"
  
  # ... other configuration ...
  
  spoke_vpcs = [
    {
      name       = "web"
      cidr_block = "10.1.0.0/16"
      allowed_ports = [80, 443]
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
}
```

### Enabling Additional Security Features

```hcl
module "organization" {
  source = "../../organization"
  
  # ... other configuration ...
  
  # Enable break glass access
  enable_break_glass_role = true
  break_glass_users = [
    "arn:aws:iam::123456789012:user/emergency-admin"
  ]
  
  # Enable GuardDuty S3 export
  enable_guardduty_s3_export = true
}
```

### Adding Management Access

```hcl
module "networking" {
  source = "../../networking"
  
  # ... other configuration ...
  
  # Allow SSH/RDP from office network
  management_cidrs = [
    "203.0.113.0/24"  # Replace with your office CIDR
  ]
}
```

## Security Features

### Enabled by Default

- **CloudTrail**: Organization-wide audit logging
- **AWS Config**: Configuration compliance monitoring
- **GuardDuty**: Threat detection and security monitoring
- **VPC Flow Logs**: Network traffic monitoring
- **KMS Encryption**: All logs encrypted at rest
- **Security Groups**: Least-privilege access patterns
- **Service Control Policies**: Prevent root account usage

### Network Security

- **Default Deny**: Security groups start with no inbound rules
- **Hub-Spoke Isolation**: Workloads isolated in separate VPCs
- **Transit Gateway**: Controlled connectivity between VPCs
- **Private Subnets**: Application workloads in private subnets
- **NAT Gateways**: Secure outbound internet access

## Cost Considerations

This basic example creates the following AWS resources with associated costs:

- **CloudTrail**: ~$2/month + S3 storage
- **Config**: ~$2/month + S3 storage  
- **GuardDuty**: ~$4.50/month + usage-based pricing
- **VPC Flow Logs**: S3 storage costs + data ingestion
- **NAT Gateways**: ~$45/month per gateway (2 gateways)
- **Transit Gateway**: ~$36/month + attachment costs
- **KMS Keys**: $1/month per key (3-4 keys)

**Estimated monthly cost**: $100-150 for basic setup

### Cost Optimization Tips

1. **Disable NAT Gateways** for development:
   ```hcl
   enable_nat_gateway = false
   ```

2. **Use CloudWatch for Flow Logs** in small environments:
   ```hcl
   flow_logs_destination = "cloudwatch"
   ```

3. **Reduce availability zones**:
   ```hcl
   availability_zone_count = 2
   ```

## Validation

After deployment, verify the setup:

### Check Organization (if created)
```bash
aws organizations describe-organization
aws organizations list-accounts
```

### Verify CloudTrail
```bash
aws cloudtrail describe-trails
aws cloudtrail get-trail-status --name <trail-name>
```

### Check GuardDuty
```bash
aws guardduty list-detectors
aws guardduty get-detector --detector-id <detector-id>
```

### Verify VPC Setup
```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*hub*"
aws ec2 describe-subnets --filters "Name=tag:Type,Values=Private"
```

### Test Connectivity
```bash
# Check Transit Gateway attachments
aws ec2 describe-transit-gateway-attachments

# Verify route tables
aws ec2 describe-route-tables --filters "Name=tag:Name,Values=*hub*"
```

## Troubleshooting

### Common Issues

1. **Organization Creation Fails**:
   - Ensure account has Organizations permissions
   - Check if organization already exists
   - Set `create_organization = false` if using existing organization

2. **CIDR Conflicts**:
   - Ensure hub and spoke CIDRs don't overlap
   - Check existing VPCs in the region

3. **Permission Errors**:
   - Verify IAM permissions for Terraform execution
   - Check AWS CLI configuration

4. **Resource Limits**:
   - Check VPC limits in your AWS account
   - Verify Transit Gateway limits

### Getting Help

1. Check Terraform state: `terraform show`
2. Review AWS CloudTrail for API errors
3. Check AWS service health dashboard
4. Review module documentation in parent directories

## Next Steps

After deploying this basic example:

1. **Deploy Applications**: Use the spoke VPC for your workloads
2. **Add Monitoring**: Set up CloudWatch dashboards and alarms
3. **Implement Backup**: Configure backup strategies for your data
4. **Security Hardening**: Review and implement additional security controls
5. **Cost Optimization**: Monitor costs and optimize based on usage

## Clean Up

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all resources created by this example. Ensure you have backups of any important data.