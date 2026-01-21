# Advanced AWS Landing Zone Example

This example demonstrates a comprehensive, production-ready AWS landing zone with full security features, multi-tier networking, and advanced monitoring capabilities.

## What This Example Creates

### Core Infrastructure
- AWS Organization with service control policies
- Multi-tier hub-spoke VPC architecture (4 tiers)
- Transit Gateway with segmented routing
- High availability across 3 availability zones

### Security Services
- CloudTrail with organization-wide logging
- AWS Config with compliance rules
- GuardDuty with threat detection and S3 export
- Security Hub with CIS and AWS Foundational standards
- Break glass emergency access roles
- Cross-account security roles

### Monitoring & Alerting
- VPC Flow Logs with long-term retention
- CloudWatch dashboard for security metrics
- SNS alerts for security events
- CloudWatch alarms for compliance monitoring

### Encryption & Data Protection
- KMS keys for all services with key rotation
- Encrypted S3 storage for all logs
- Secure transport enforcement

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS Organization                         │
│  ┌─────────────────┐              ┌─────────────────┐          │
│  │  Security OU    │              │  Workloads OU   │          │
│  │                 │              │                 │          │
│  └─────────────────┘              └─────────────────┘          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                        Hub VPC (10.0.0.0/16)                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│  │   Public    │ │   Public    │ │   Public    │              │
│  │  Subnet     │ │  Subnet     │ │  Subnet     │              │
│  │   (AZ-1)    │ │   (AZ-2)    │ │   (AZ-3)    │              │
│  │ NAT Gateway │ │ NAT Gateway │ │ NAT Gateway │              │
│  └─────────────┘ └─────────────┘ └─────────────┘              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐              │
│  │   Private   │ │   Private   │ │   Private   │              │
│  │  Subnet     │ │  Subnet     │ │  Subnet     │              │
│  │   (AZ-1)    │ │   (AZ-2)    │ │   (AZ-3)    │              │
│  └─────────────┘ └─────────────┘ └─────────────┘              │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────────────┐
                    │ Transit Gateway │
                    │   (Segmented    │
                    │  Route Tables)  │
                    └─────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│   Web Tier    │    │   App Tier    │    │   Data Tier   │
│ (10.1.0.0/16) │    │ (10.2.0.0/16) │    │ (10.3.0.0/16) │
│   DMZ Zone    │    │  App Logic    │    │  Databases    │
└───────────────┘    └───────────────┘    └───────────────┘
                              │
                    ┌───────────────┐
                    │   Mgmt Tier   │
                    │ (10.4.0.0/16) │
                    │  Jump Boxes   │
                    └───────────────┘
```

## Usage

### Prerequisites

1. **AWS Account Setup**:
   - AWS CLI configured with OrganizationsFullAccess
   - Terraform >= 1.0 installed
   - Appropriate IAM permissions for all services

2. **Security Requirements**:
   - Secure external ID for cross-account access
   - Break glass user ARNs identified
   - Management network CIDRs defined

### Deployment Steps

1. **Clone and navigate**:
   ```bash
   cd modules/aws/examples/advanced
   ```

2. **Create terraform.tfvars**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit with your specific values
   ```

3. **Initialize and deploy**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

### Required Configuration

Create `terraform.tfvars` with your specific values:

```hcl
# Basic configuration
aws_region        = "us-west-2"
organization_name = "mycompany"
environment      = "prod"

# Security configuration
create_organization = true
security_account_id = "123456789012"  # Your security account ID
external_id        = "secure-random-external-id-here"

# Break glass users (replace with actual ARNs)
break_glass_users = [
  "arn:aws:iam::123456789012:user/emergency-admin-1",
  "arn:aws:iam::123456789012:user/emergency-admin-2"
]

# Network configuration
hub_vpc_cidr           = "10.0.0.0/16"
availability_zone_count = 3

# Management access (replace with your networks)
management_cidrs = [
  "203.0.113.0/24",   # Office network
  "198.51.100.0/24"   # VPN network
]

# Compliance and monitoring
flow_logs_retention_days = 2555  # 7 years for compliance

# Tags
tags = {
  Owner       = "platform-team"
  Environment = "prod"
  Compliance  = "SOC2"
  CostCenter  = "infrastructure"
}
```

## Security Features

### Identity & Access Management
- **Service Control Policies**: Prevent root account usage and critical service disabling
- **Cross-Account Roles**: Secure access from security account with external ID
- **Break Glass Access**: Emergency administrative access with MFA requirement
- **Least Privilege**: All roles follow minimal access principles

### Network Security
- **Segmented Architecture**: Four-tier network isolation (web/app/data/mgmt)
- **Transit Gateway**: Controlled routing between network segments
- **Security Groups**: Layered security with default-deny policies
- **VPC Flow Logs**: Comprehensive network traffic monitoring
- **Private Subnets**: Application workloads isolated from internet

### Monitoring & Compliance
- **CloudTrail**: Organization-wide API logging with encryption
- **AWS Config**: Configuration compliance monitoring with security rules
- **GuardDuty**: AI-powered threat detection with S3 export
- **Security Hub**: Centralized security findings with CIS benchmarks
- **CloudWatch**: Real-time monitoring with automated alerting

### Data Protection
- **Encryption at Rest**: All data encrypted with customer-managed KMS keys
- **Encryption in Transit**: TLS enforcement for all communications
- **Key Rotation**: Automatic KMS key rotation enabled
- **Secure Storage**: S3 buckets with versioning and lifecycle policies

## Compliance Frameworks

This configuration supports multiple compliance frameworks:

### SOC 2 Type II
- Comprehensive audit logging
- Access controls and monitoring
- Data encryption and protection
- Incident response capabilities

### CIS AWS Foundations Benchmark
- Security Hub CIS standard enabled
- Config rules for CIS controls
- Network security baselines
- IAM security configurations

### NIST Cybersecurity Framework
- Identify: Asset inventory and risk assessment
- Protect: Access controls and data protection
- Detect: Continuous monitoring and alerting
- Respond: Incident response procedures
- Recover: Backup and recovery capabilities

## Cost Analysis

### Monthly Cost Estimate (Production)

| Service | Cost | Notes |
|---------|------|-------|
| CloudTrail | $2 | + S3 storage costs |
| Config | $2 | + S3 storage costs |
| GuardDuty | $4.50 | + usage-based pricing |
| Security Hub | $1.20 | Per security check |
| VPC Flow Logs | Variable | Based on traffic volume |
| NAT Gateways | $135 | 3 gateways × $45/month |
| Transit Gateway | $36 | + attachment costs |
| KMS Keys | $4 | 4 keys × $1/month |
| S3 Storage | Variable | Based on log volume |
| **Total Base Cost** | **~$185/month** | Excluding usage-based charges |

### Cost Optimization Options

1. **Development Environment**:
   - Reduce to 2 AZs: Save ~$45/month (1 NAT gateway)
   - Shorter log retention: Reduce S3 costs
   - Disable GuardDuty S3 export: Save storage costs

2. **Test Environment**:
   - Use CloudWatch for Flow Logs: Better for smaller volumes
   - Reduce spoke VPCs: Lower Transit Gateway costs
   - Shorter retention periods: Reduce storage costs

## Monitoring & Alerting

### CloudWatch Dashboard

The deployment creates a comprehensive dashboard showing:
- Security metrics (GuardDuty findings, Config compliance)
- Network traffic analysis from Flow Logs
- Top rejected source IPs
- Service health indicators

Access: `https://console.aws.amazon.com/cloudwatch/home#dashboards`

### Automated Alerts

SNS topic configured for:
- High-severity GuardDuty findings
- Config compliance violations
- Security Hub critical findings
- CloudTrail API anomalies

### Log Analysis

VPC Flow Logs stored in S3 with:
- Parquet format for efficient querying
- Partitioned by date and hour
- Lifecycle policies for cost optimization
- CloudWatch Insights integration

## Validation & Testing

### Post-Deployment Validation

1. **Organization Setup**:
   ```bash
   aws organizations describe-organization
   aws organizations list-organizational-units-for-parent --parent-id <root-id>
   ```

2. **Security Services**:
   ```bash
   # CloudTrail
   aws cloudtrail describe-trails
   aws cloudtrail get-trail-status --name <trail-name>
   
   # GuardDuty
   aws guardduty list-detectors
   aws guardduty get-detector --detector-id <detector-id>
   
   # Config
   aws configservice describe-configuration-recorders
   aws configservice describe-config-rules
   
   # Security Hub
   aws securityhub get-enabled-standards
   ```

3. **Network Connectivity**:
   ```bash
   # VPC setup
   aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*hub*"
   aws ec2 describe-transit-gateways
   
   # Security groups
   aws ec2 describe-security-groups --group-names "*default*"
   ```

### Security Testing

1. **Access Controls**:
   - Test break glass role assumption
   - Verify cross-account access works
   - Validate MFA requirements

2. **Network Security**:
   - Test spoke-to-spoke isolation
   - Verify security group rules
   - Check NAT gateway functionality

3. **Monitoring**:
   - Generate test GuardDuty findings
   - Trigger Config rule violations
   - Verify alert notifications

## Troubleshooting

### Common Issues

1. **Organization Creation**:
   ```bash
   # Check if organization exists
   aws organizations describe-organization
   
   # If exists, set create_organization = false
   ```

2. **Permission Errors**:
   ```bash
   # Verify IAM permissions
   aws sts get-caller-identity
   aws iam list-attached-role-policies --role-name <terraform-role>
   ```

3. **Network Connectivity**:
   ```bash
   # Check Transit Gateway routes
   aws ec2 describe-transit-gateway-route-tables
   aws ec2 search-transit-gateway-routes --transit-gateway-route-table-id <rt-id>
   ```

4. **Security Service Issues**:
   ```bash
   # Check service status
   aws guardduty list-detectors
   aws configservice describe-configuration-recorder-status
   aws securityhub get-findings --max-items 5
   ```

### Support Resources

- AWS CloudTrail for API call history
- AWS Config for resource configuration changes
- AWS Support for service-specific issues
- Terraform state file for resource relationships

## Customization

### Adding Custom Security Controls

```hcl
# Additional Config rules
resource "aws_config_config_rule" "custom_rule" {
  name = "custom-security-rule"
  
  source {
    owner             = "AWS"
    source_identifier = "CUSTOM_RULE_IDENTIFIER"
  }
}
```

### Extending Monitoring

```hcl
# Additional CloudWatch alarms
resource "aws_cloudwatch_metric_alarm" "custom_alarm" {
  alarm_name          = "custom-security-alarm"
  comparison_operator = "GreaterThanThreshold"
  # ... configuration
}
```

### Multi-Region Deployment

```hcl
# Additional provider for second region
provider "aws" {
  alias  = "secondary"
  region = "us-east-1"
}

# Deploy modules in secondary region
module "organization_secondary" {
  source = "../../organization"
  providers = {
    aws = aws.secondary
  }
  # ... configuration
}
```

## Next Steps

1. **Application Deployment**: Deploy workloads to spoke VPCs
2. **Backup Strategy**: Implement backup for critical data
3. **Disaster Recovery**: Set up cross-region replication
4. **Security Hardening**: Implement additional security controls
5. **Cost Optimization**: Monitor and optimize based on usage
6. **Compliance Reporting**: Set up automated compliance reports

## Clean Up

**Warning**: This will destroy all resources and data.

```bash
terraform destroy
```

Ensure you have:
- Backed up any important data
- Documented any custom configurations
- Notified stakeholders of the destruction