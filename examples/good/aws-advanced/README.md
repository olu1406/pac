# AWS Advanced Secure Configuration

This example demonstrates an advanced AWS setup that passes all security controls. It includes a more complex multi-tier architecture with additional security features and compliance controls.

## Security Features

### Enhanced Identity & Access Management
- **Cross-Account Roles**: Secure cross-account access patterns
- **Service-Linked Roles**: Proper service integration with minimal permissions
- **Policy Conditions**: Advanced IAM policy conditions for enhanced security
- **Resource-Based Policies**: Fine-grained resource access control

### Advanced Networking
- **Multi-AZ Architecture**: High availability across multiple availability zones
- **Network ACLs**: Additional layer of network security
- **VPC Endpoints**: Private connectivity to AWS services
- **Transit Gateway**: Scalable network connectivity (simulated)

### Enhanced Data Protection
- **KMS Encryption**: Customer-managed keys for enhanced encryption
- **Cross-Region Replication**: Data durability and disaster recovery
- **Lifecycle Policies**: Automated data management
- **Access Point**: Controlled S3 access patterns

### Comprehensive Monitoring
- **Config Rules**: Automated compliance monitoring
- **GuardDuty**: Advanced threat detection
- **Security Hub**: Centralized security findings
- **EventBridge**: Security event automation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Account                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │   Public Subnet │    │   Public Subnet │                │
│  │      AZ-1a      │    │      AZ-1b      │                │
│  │   ┌─────────┐   │    │   ┌─────────┐   │                │
│  │   │   ALB   │   │    │   │   NAT   │   │                │
│  │   └─────────┘   │    │   └─────────┘   │                │
│  └─────────────────┘    └─────────────────┘                │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  Private Subnet │    │  Private Subnet │                │
│  │      AZ-1a      │    │      AZ-1b      │                │
│  │   ┌─────────┐   │    │   ┌─────────┐   │                │
│  │   │   App   │   │    │   │   App   │   │                │
│  │   └─────────┘   │    │   └─────────┘   │                │
│  └─────────────────┘    └─────────────────┘                │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │ Database Subnet │    │ Database Subnet │                │
│  │      AZ-1a      │    │      AZ-1b      │                │
│  │   ┌─────────┐   │    │   ┌─────────┐   │                │
│  │   │   RDS   │   │    │   │   RDS   │   │                │
│  │   └─────────┘   │    │   └─────────┘   │                │
│  └─────────────────┘    └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Resources Created

### Networking
- Multi-AZ VPC with 6 subnets (2 public, 2 private, 2 database)
- Internet Gateway and 2 NAT Gateways for high availability
- Network ACLs for additional security layers
- VPC Endpoints for S3 and DynamoDB

### Security Groups
- Application Load Balancer security group
- Web tier security group
- Application tier security group
- Database tier security group
- All with principle of least privilege

### Storage & Encryption
- KMS keys for encryption
- S3 buckets with advanced security features
- Cross-region replication
- S3 Access Points for controlled access

### Identity & Access
- Multiple IAM roles for different tiers
- Cross-account access roles
- Service-linked roles
- Advanced policy conditions

### Monitoring & Compliance
- CloudTrail with data events
- Config with compliance rules
- GuardDuty for threat detection
- VPC Flow Logs
- CloudWatch alarms

## Usage

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan -var-file="terraform.tfvars"

# Apply the configuration
terraform apply -var-file="terraform.tfvars"

# Test with policy validation
TERRAFORM_DIR=examples/good/aws-advanced make scan
```

## Security Compliance

This configuration satisfies all security controls and demonstrates advanced patterns:

- **Enhanced IAM Controls**: Advanced policy conditions and cross-account access
- **Network Segmentation**: Multi-tier architecture with proper isolation
- **Data Protection**: Customer-managed encryption and cross-region replication
- **Monitoring**: Comprehensive logging and threat detection
- **Compliance**: Automated compliance monitoring with Config rules

All controls are validated through automated policy checks with zero violations expected.