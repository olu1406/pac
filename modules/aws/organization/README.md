# AWS Organization and Account Baseline Module

This Terraform module creates a secure AWS Organizations setup with comprehensive security baselines including IAM roles, CloudTrail logging, AWS Config compliance monitoring, and GuardDuty threat detection. It implements security best practices and provides a foundation for enterprise AWS deployments.

## Features

- **AWS Organizations**: Secure organization setup with organizational units
- **Service Control Policies**: Baseline security controls preventing dangerous actions
- **IAM Baseline**: Cross-account roles and emergency access procedures
- **CloudTrail**: Organization-wide audit logging with encryption
- **AWS Config**: Compliance monitoring and configuration recording
- **GuardDuty**: Threat detection and security monitoring
- **Encryption**: KMS keys for all security services
- **Compliance Framework Support**: Maps to NIST 800-53, ISO 27001, and CIS benchmarks

## Architecture

```
AWS Organization
├── Root OU
│   ├── Security OU
│   ├── Workloads OU
│   └── Sandbox OU
├── Service Control Policies
├── CloudTrail (Organization-wide)
├── AWS Config (Compliance monitoring)
└── GuardDuty (Threat detection)
```

## Usage

### Basic Usage

```hcl
module "aws_organization" {
  source = "./modules/aws/organization"

  organization_name = "mycompany"
  environment      = "prod"

  # Organization configuration
  create_organization = true

  # Security configuration
  security_account_id = "123456789012"
  external_id        = "unique-external-id-change-me"

  # Emergency access
  enable_break_glass_role = true
  break_glass_users = [
    "arn:aws:iam::123456789012:user/emergency-admin-1",
    "arn:aws:iam::123456789012:user/emergency-admin-2"
  ]

  # GuardDuty configuration
  enable_guardduty_s3_export = true

  tags = {
    Environment = "Production"
    Owner       = "Platform Team"
  }
}
```

### Advanced Usage with Threat Intelligence

```hcl
module "aws_organization" {
  source = "./modules/aws/organization"

  organization_name = "mycompany"
  environment      = "prod"

  # Organization configuration
  create_organization = true

  # Security configuration
  security_account_id = "123456789012"
  external_id        = "unique-external-id-change-me"

  # Emergency access
  enable_break_glass_role = true
  break_glass_users = [
    "arn:aws:iam::123456789012:user/emergency-admin-1",
    "arn:aws:iam::123456789012:user/emergency-admin-2"
  ]

  # GuardDuty configuration
  enable_guardduty_s3_export = true
  
  # Threat intelligence sets
  threat_intel_sets = [
    {
      name     = "custom-threat-intel"
      format   = "TXT"
      location = "s3://your-threat-intel-bucket/threat-ips.txt"
    }
  ]

  # Trusted IP sets
  trusted_ip_sets = [
    {
      name     = "trusted-office-ips"
      format   = "TXT"
      location = "s3://your-config-bucket/trusted-ips.txt"
    }
  ]

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
| aws | ~> 5.0 |
| random | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 5.0 |
| random | ~> 3.0 |

## Resources Created

### AWS Organizations
- AWS Organization with all features enabled
- Organizational Units (Security, Workloads, Sandbox)
- Service Control Policies for security baseline
- Policy attachments

### IAM Baseline
- Cross-account security role for centralized security account access
- Break glass emergency access role with MFA requirement
- CloudFormation execution role for infrastructure deployment
- Appropriate policy attachments

### CloudTrail
- Organization-wide CloudTrail with multi-region support
- S3 bucket with versioning and encryption
- KMS key for CloudTrail log encryption
- Proper bucket policies and access controls
- Data event logging for S3 objects
- CloudTrail Insights for anomaly detection

### AWS Config
- Configuration recorder for all resource types
- Delivery channel with daily snapshots
- S3 bucket for configuration history
- KMS key for Config encryption
- IAM role with appropriate permissions

### GuardDuty
- GuardDuty detector with all data sources enabled
- S3 logs monitoring
- Kubernetes audit logs monitoring
- Malware protection for EC2 instances
- Optional S3 export for findings
- Support for threat intelligence and trusted IP sets

### Encryption
- KMS keys for CloudTrail, Config, and GuardDuty
- Key rotation enabled
- Appropriate key policies for service access

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| organization_name | Name of the organization | `string` | n/a | yes |
| environment | Environment name (dev, test, prod) | `string` | `"prod"` | no |
| create_organization | Whether to create AWS Organizations | `bool` | `true` | no |
| security_account_id | AWS account ID for security account | `string` | `""` | no |
| external_id | External ID for cross-account role assumption | `string` | `""` | no |
| enable_break_glass_role | Whether to create break glass role | `bool` | `false` | no |
| break_glass_users | List of IAM user ARNs for break glass access | `list(string)` | `[]` | no |
| enable_guardduty_s3_export | Whether to enable GuardDuty S3 export | `bool` | `false` | no |

See [variables.tf](./variables.tf) for complete list of inputs.

## Outputs

| Name | Description |
|------|-------------|
| organization_id | The organization ID |
| organization_arn | The organization ARN |
| security_ou_id | The Security organizational unit ID |
| cloudtrail_arn | ARN of the organization CloudTrail |
| guardduty_detector_id | ID of the GuardDuty detector |

See [outputs.tf](./outputs.tf) for complete list of outputs.

## Security Considerations

### Service Control Policies
- Denies root user actions across all accounts
- Prevents disabling of CloudTrail and Config
- Enforces security baseline across organization

### IAM Best Practices
- Cross-account roles use external ID for additional security
- Break glass roles require MFA authentication
- Least-privilege access principles applied

### Encryption and Data Protection
- All logs encrypted with customer-managed KMS keys
- S3 buckets have versioning and public access blocked
- Key rotation enabled for all KMS keys

### Monitoring and Compliance
- Organization-wide CloudTrail captures all API calls
- AWS Config monitors configuration compliance
- GuardDuty provides threat detection and security monitoring

### Compliance Framework Mapping
- Maps to NIST 800-53 controls (AU-2, AU-3, AU-6, SI-4)
- Supports ISO 27001 requirements (A.12.4.1, A.12.4.2, A.12.4.3)
- Implements CIS AWS Foundations Benchmark controls

## Post-Deployment Steps

### 1. Configure Cross-Account Access
```bash
# Test cross-account role assumption
aws sts assume-role \
  --role-arn "arn:aws:iam::ACCOUNT-ID:role/mycompany-cross-account-security" \
  --role-session-name "security-audit" \
  --external-id "your-external-id"
```

### 2. Set Up Config Rules
```bash
# Deploy additional Config rules for compliance
aws configservice put-config-rule \
  --config-rule file://config-rules.json
```

### 3. Configure GuardDuty Notifications
```bash
# Set up SNS topic for GuardDuty findings
aws sns create-topic --name guardduty-findings
```

### 4. Review CloudTrail Logs
```bash
# Query CloudTrail logs in CloudWatch Logs Insights
aws logs start-query \
  --log-group-name "CloudTrail/mycompany-organization-trail" \
  --start-time $(date -d '1 hour ago' +%s) \
  --end-time $(date +%s) \
  --query-string 'fields @timestamp, sourceIPAddress, userIdentity.type, eventName'
```

## Cost Optimization

For development environments, consider:

```hcl
# Reduce costs by disabling optional features
enable_guardduty_s3_export = false  # Disable S3 export
threat_intel_sets         = []      # No custom threat intel
trusted_ip_sets          = []      # No custom trusted IPs
```

## Troubleshooting

### Common Issues

1. **Organization Creation Permissions**
   ```bash
   # Ensure account has organizations:CreateOrganization permission
   aws organizations describe-organization
   ```

2. **CloudTrail S3 Permissions**
   ```bash
   # Verify CloudTrail can write to S3 bucket
   aws cloudtrail get-trail-status --name mycompany-organization-trail
   ```

3. **Config Delivery Channel**
   ```bash
   # Check Config delivery channel status
   aws configservice describe-delivery-channels
   ```

### Getting Help

- Review AWS Organizations [documentation](https://docs.aws.amazon.com/organizations/)
- Check CloudTrail [troubleshooting guide](https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-troubleshooting.html)
- Consult AWS Config [FAQ](https://aws.amazon.com/config/faq/)

## Examples

See the [examples](../examples/) directory for complete usage examples:
- [Basic organization setup](../examples/basic/)
- [Advanced enterprise configuration](../examples/advanced/)

## Contributing

Please read [CONTRIBUTING.md](../../../CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This module is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.