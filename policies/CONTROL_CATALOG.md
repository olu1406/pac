# Security Control Catalog

## Overview

This document provides a comprehensive catalog of all security controls implemented in the Multi-Cloud Security Policy system. Each control is mapped to relevant compliance frameworks and includes severity levels, remediation guidance, and implementation details.

## Control ID System

Controls follow a structured naming convention:
- **AWS Controls**: `{DOMAIN}-{NUMBER}` (e.g., `IAM-001`, `NET-001`, `LOG-001`, `DATA-001`)
- **Azure Controls**: `AZ-{DOMAIN}-{NUMBER}` (e.g., `AZ-IAM-001`, `AZ-NET-001`, `AZ-LOG-001`, `AZ-DATA-001`)

### Severity Levels
- **CRITICAL**: Immediate security risk, must be addressed
- **HIGH**: Significant security risk, should be addressed promptly
- **MEDIUM**: Moderate security risk, should be addressed in planned maintenance
- **LOW**: Minor security risk, can be addressed when convenient

### Framework Mappings
- **NIST-800-53**: NIST Special Publication 800-53 Security Controls
- **CIS**: Center for Internet Security Benchmarks
- **ISO-27001**: ISO/IEC 27001 Information Security Management

## AWS Security Controls

### Identity & Access Management (IAM)

| Control ID | Title | Severity | NIST 800-53 | CIS-AWS | ISO 27001 | Description |
|------------|-------|----------|-------------|---------|-----------|-------------|
| IAM-001 | IAM policies must not allow wildcard actions on all resources | CRITICAL | AC-6 | 1.16 | A.9.2.3 | Prevents overly permissive IAM policies with wildcard actions |
| IAM-002 | IAM users must not have inline policies | HIGH | AC-2 | 1.15 | A.9.2.1 | Enforces use of managed policies over inline policies |
| IAM-003 | IAM roles must have trust policy with specific principals | HIGH | AC-3 | 1.17 | A.9.1.2 | Prevents overly permissive trust policies |
| IAM-004 | Root access keys must not be created | CRITICAL | AC-2 | 1.4 | A.9.2.1 | Prevents creation of root user access keys |
| IAM-005 | IAM users with console access must have MFA enabled | HIGH | IA-2 | 1.2 | A.9.4.2 | Enforces MFA for console access |
| IAM-006 | Password policy must meet security requirements | MEDIUM | IA-5 | 1.8 | A.9.4.3 | Enforces strong password policies |

### Networking (NET)

| Control ID | Title | Severity | NIST 800-53 | CIS-AWS | ISO 27001 | Description |
|------------|-------|----------|-------------|---------|-----------|-------------|
| NET-001 | No public SSH access from 0.0.0.0/0 | CRITICAL | AC-4 | 4.1 | A.13.1.1 | Prevents unrestricted SSH access |
| NET-002 | No public RDP access from 0.0.0.0/0 | CRITICAL | AC-4 | 4.2 | A.13.1.1 | Prevents unrestricted RDP access |
| NET-003 | Default security group should not allow any traffic | HIGH | AC-4 | 4.3 | A.13.1.1 | Secures default security groups |
| NET-004 | Security groups should not allow unrestricted outbound traffic | MEDIUM | AC-4 | 4.4 | A.13.1.1 | Limits outbound traffic scope |
| NET-005 | VPC Flow Logs must be enabled | HIGH | AU-2 | 2.9 | A.12.4.1 | Enables network traffic logging |
| NET-006 | VPC must not use default VPC | MEDIUM | AC-4 | 2.1 | A.13.1.1 | Enforces custom VPC usage |
| NET-007 | Subnets should not auto-assign public IP addresses | MEDIUM | AC-4 | 2.2 | A.13.1.1 | Prevents automatic public IP assignment |
| NET-008 | Network ACLs should not allow unrestricted access | HIGH | AC-4 | 4.5 | A.13.1.1 | Secures Network ACL rules |

### Logging & Monitoring (LOG)

| Control ID | Title | Severity | NIST 800-53 | CIS-AWS | ISO 27001 | Description |
|------------|-------|----------|-------------|---------|-----------|-------------|
| LOG-001 | CloudTrail must be enabled in all regions | CRITICAL | AU-2 | 2.1 | A.12.4.1 | Enables comprehensive audit logging |
| LOG-002 | CloudTrail log file validation must be enabled | HIGH | AU-9 | 2.2 | A.12.4.2 | Ensures log integrity |
| LOG-003 | CloudTrail logs must be encrypted at rest | HIGH | SC-28 | 2.7 | A.10.1.1 | Protects audit logs with encryption |
| LOG-004 | CloudTrail must include management events | MEDIUM | AU-2 | 2.3 | A.12.4.1 | Ensures comprehensive event logging |
| LOG-005 | CloudTrail S3 bucket must not be publicly accessible | CRITICAL | AC-3 | 2.3 | A.9.1.2 | Protects audit log storage |
| LOG-006 | AWS Config must be enabled | HIGH | CM-8 | 2.5 | A.12.5.1 | Enables configuration tracking |
| LOG-007 | AWS Config delivery channel must be configured | HIGH | CM-8 | 2.5 | A.12.5.1 | Ensures config data delivery |
| LOG-008 | AWS Config recorder must record all resource types | MEDIUM | CM-8 | 2.5 | A.12.5.1 | Comprehensive resource tracking |
| LOG-009 | AWS Config must include global resource types | MEDIUM | CM-8 | 2.5 | A.12.5.1 | Includes global AWS resources |

### Data Protection (DATA)

| Control ID | Title | Severity | NIST 800-53 | CIS-AWS | ISO 27001 | Description |
|------------|-------|----------|-------------|---------|-----------|-------------|
| DATA-001 | S3 buckets must have server-side encryption enabled | HIGH | SC-28 | 2.1.1 | A.10.1.1 | Encrypts S3 data at rest |
| DATA-002 | S3 buckets must block public access | CRITICAL | AC-3 | 2.1.5 | A.9.1.2 | Prevents public S3 access |
| DATA-003 | S3 buckets must have versioning enabled | MEDIUM | CP-9 | 2.1.3 | A.12.3.1 | Enables data versioning |
| DATA-004 | S3 buckets must have access logging enabled | MEDIUM | AU-2 | 2.1.4 | A.12.4.1 | Logs S3 access events |
| DATA-005 | EBS volumes must be encrypted | HIGH | SC-28 | 2.2.1 | A.10.1.1 | Encrypts EBS storage |
| DATA-006 | EBS snapshots must be encrypted | HIGH | SC-28 | 2.2.1 | A.10.1.1 | Encrypts EBS backups |
| DATA-007 | RDS instances must be encrypted at rest | HIGH | SC-28 | 2.3.1 | A.10.1.1 | Encrypts database storage |
| DATA-008 | RDS snapshots must be encrypted | HIGH | SC-28 | 2.3.1 | A.10.1.1 | Encrypts database backups |

## Azure Security Controls

### Identity & Access Management (AZ-IAM)

| Control ID | Title | Severity | NIST 800-53 | CIS-Azure | ISO 27001 | Description |
|------------|-------|----------|-------------|-----------|-----------|-------------|
| AZ-IAM-001 | Custom RBAC roles must not have wildcard permissions | CRITICAL | AC-6 | 1.21 | A.9.2.3 | Prevents overly permissive RBAC roles |
| AZ-IAM-002 | Role assignments must not grant Owner permissions at subscription scope | HIGH | AC-2 | 1.1 | A.9.2.1 | Limits subscription-level Owner access |
| AZ-IAM-003 | Service principals must not have permanent credentials | MEDIUM | AC-2 | 1.2 | A.9.2.1 | Enforces credential expiration |
| AZ-IAM-004 | Guest users must be reviewed regularly | MEDIUM | AC-2 | 1.3 | A.9.2.1 | Ensures guest user governance |
| AZ-IAM-005 | Administrative accounts must require MFA | HIGH | IA-2 | 1.1 | A.9.4.2 | Enforces MFA for privileged access |
| AZ-IAM-006 | Privileged roles should use Privileged Identity Management (PIM) | HIGH | AC-2 | 1.15 | A.9.2.1 | Promotes just-in-time access |
| AZ-IAM-007 | Break-glass accounts must be monitored | HIGH | AC-2 | 1.16 | A.9.2.1 | Ensures emergency account oversight |
| AZ-IAM-008 | Service principal credentials must have limited scope | MEDIUM | AC-6 | 1.23 | A.9.2.3 | Limits service principal permissions |

### Networking (AZ-NET)

| Control ID | Title | Severity | NIST 800-53 | CIS-Azure | ISO 27001 | Description |
|------------|-------|----------|-------------|-----------|-----------|-------------|
| AZ-NET-001 | Network Security Groups must not allow SSH from any source | CRITICAL | AC-4 | 6.1 | A.13.1.1 | Prevents unrestricted SSH access |
| AZ-NET-002 | Network Security Groups must not allow RDP from any source | CRITICAL | AC-4 | 6.2 | A.13.1.1 | Prevents unrestricted RDP access |
| AZ-NET-003 | Network Security Groups must not allow unrestricted inbound access | HIGH | AC-4 | 6.3 | A.13.1.1 | Limits inbound traffic scope |
| AZ-NET-004 | Default Network Security Group rules should be reviewed | MEDIUM | AC-4 | 6.4 | A.13.1.1 | Ensures explicit security rules |
| AZ-NET-005 | Network Security Groups should deny high-risk ports | HIGH | AC-4 | 6.5 | A.13.1.1 | Blocks dangerous port access |
| AZ-NET-006 | Virtual Networks must have Network Security Groups associated | HIGH | AC-4 | 6.6 | A.13.1.1 | Ensures subnet protection |
| AZ-NET-007 | Virtual Networks should enable DDoS protection | MEDIUM | SC-5 | 6.7 | A.13.1.1 | Protects against DDoS attacks |
| AZ-NET-008 | Virtual Network peering should not allow gateway transit from untrusted networks | HIGH | AC-4 | 6.8 | A.13.1.1 | Secures network peering |
| AZ-NET-009 | Subnets should not have public IP addresses auto-assigned | MEDIUM | AC-4 | 6.9 | A.13.1.1 | Prevents automatic public exposure |
| AZ-NET-010 | Network Watcher flow logs should be enabled | MEDIUM | AU-2 | 6.5 | A.12.4.1 | Enables network traffic logging |

### Logging & Monitoring (AZ-LOG)

| Control ID | Title | Severity | NIST 800-53 | CIS-Azure | ISO 27001 | Description |
|------------|-------|----------|-------------|-----------|-----------|-------------|
| AZ-LOG-001 | Activity Log retention should be set to at least 90 days | MEDIUM | AU-4 | 5.1.1 | A.12.4.1 | Ensures adequate log retention |
| AZ-LOG-002 | Activity Logs should be exported to Log Analytics workspace | HIGH | AU-6 | 5.1.2 | A.12.4.1 | Centralizes log analysis |
| AZ-LOG-003 | Security Center should have email notifications enabled | MEDIUM | IR-6 | 2.13 | A.16.1.2 | Enables security alerting |
| AZ-LOG-004 | Key Vault should have diagnostic logging enabled | HIGH | AU-2 | 5.1.5 | A.12.4.1 | Logs Key Vault access |
| AZ-LOG-005 | Storage Account should have diagnostic logging enabled | MEDIUM | AU-2 | 5.1.6 | A.12.4.1 | Logs storage access |
| AZ-LOG-006 | Security Center standard tier should be enabled | HIGH | SI-4 | 2.1 | A.12.6.1 | Enables advanced threat detection |
| AZ-LOG-007 | Security Center auto-provisioning should be enabled | MEDIUM | SI-4 | 2.2 | A.12.6.1 | Automates agent deployment |
| AZ-LOG-008 | Security Center should have default policy assignment | MEDIUM | SI-4 | 2.15 | A.12.6.1 | Ensures policy compliance |
| AZ-LOG-009 | Log Analytics workspace should have appropriate retention | MEDIUM | AU-4 | 5.1.3 | A.12.4.1 | Maintains log history |
| AZ-LOG-010 | Network Security Group flow logs should be retained for at least 90 days | MEDIUM | AU-4 | 6.5 | A.12.4.1 | Preserves network logs |

### Data Protection (AZ-DATA)

| Control ID | Title | Severity | NIST 800-53 | CIS-Azure | ISO 27001 | Description |
|------------|-------|----------|-------------|-----------|-----------|-------------|
| AZ-DATA-001 | Storage Accounts must have encryption enabled | HIGH | SC-28 | 3.1 | A.10.1.1 | Enforces HTTPS-only access |
| AZ-DATA-002 | Storage Accounts must not allow public blob access | CRITICAL | AC-3 | 3.7 | A.9.1.2 | Prevents public storage access |
| AZ-DATA-003 | Storage Account containers must not have public access | CRITICAL | AC-3 | 3.8 | A.9.1.2 | Secures container access |
| AZ-DATA-004 | Storage Accounts should use customer-managed keys for encryption | MEDIUM | SC-28 | 3.2 | A.10.1.1 | Enhances encryption control |
| AZ-DATA-005 | Storage Accounts should have minimum TLS version set to 1.2 | HIGH | SC-8 | 3.15 | A.13.1.1 | Enforces secure transport |
| AZ-DATA-006 | Storage Accounts should have soft delete enabled for blobs | MEDIUM | CP-9 | 3.11 | A.12.3.1 | Enables data recovery |
| AZ-DATA-007 | SQL Database must have Transparent Data Encryption enabled | HIGH | SC-28 | 4.1.1 | A.10.1.1 | Encrypts database data |
| AZ-DATA-008 | SQL Server must have auditing enabled | HIGH | AU-2 | 4.1.3 | A.12.4.1 | Logs database access |
| AZ-DATA-009 | SQL Server must not allow Azure services access by default | MEDIUM | AC-4 | 4.2.1 | A.13.1.1 | Restricts database access |
| AZ-DATA-010 | Key Vault keys must have expiration dates | MEDIUM | SC-12 | 8.1 | A.10.1.2 | Enforces key rotation |
| AZ-DATA-011 | Key Vault secrets must have expiration dates | MEDIUM | SC-12 | 8.2 | A.10.1.2 | Enforces secret rotation |
| AZ-DATA-012 | Key Vault must have soft delete enabled | HIGH | CP-9 | 8.4 | A.12.3.1 | Protects against accidental deletion |

## Control Usage Guidelines

### Enabling/Disabling Controls

Controls can be enabled or disabled by commenting/uncommenting the control blocks in the Rego policy files:

```rego
# To disable a control, comment out the entire control block:
# deny contains msg if {
#     # Control logic here
# }

# To enable a control, ensure the block is uncommented:
deny contains msg if {
    # Control logic here
}
```

### Adding New Controls

When adding new controls:

1. Follow the naming convention: `{CLOUD}-{DOMAIN}-{NUMBER}`
2. Include all required metadata in comments
3. Map to at least one compliance framework
4. Assign appropriate severity level
5. Provide clear remediation guidance
6. Update this catalog document

### Framework Mapping Reference

#### NIST 800-53 Control Families
- **AC**: Access Control
- **AU**: Audit and Accountability  
- **CM**: Configuration Management
- **CP**: Contingency Planning
- **IA**: Identification and Authentication
- **IR**: Incident Response
- **SC**: System and Communications Protection
- **SI**: System and Information Integrity

#### CIS Benchmark Sections
- **AWS**: CIS Amazon Web Services Foundations Benchmark
- **Azure**: CIS Microsoft Azure Foundations Benchmark

#### ISO 27001 Annex A Controls
- **A.9**: Access Control
- **A.10**: Cryptography
- **A.12**: Operations Security
- **A.13**: Communications Security
- **A.16**: Information Security Incident Management

## Compliance Matrix Export

The system supports exporting compliance matrices in multiple formats:

- **CSV**: For spreadsheet analysis
- **JSON**: For programmatic processing
- **Markdown**: For documentation

Use the provided scripts to generate these exports based on the current control catalog.