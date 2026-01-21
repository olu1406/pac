# Security Policy Controls

This directory contains the security policy controls implemented as Open Policy Agent (OPA) Rego policies for the Multi-Cloud Security Policy system.

## Directory Structure

```
policies/
├── README.md                    # This file
├── CONTROL_CATALOG.md          # Comprehensive control catalog with framework mappings
├── control_metadata.json       # Machine-readable control metadata
├── aws/                        # AWS-specific security controls
│   ├── identity/               # IAM and identity controls
│   ├── networking/             # VPC and networking controls
│   ├── logging/                # CloudTrail and Config controls
│   └── data/                   # S3, EBS, and RDS encryption controls
├── azure/                      # Azure-specific security controls
│   ├── identity/               # RBAC and identity controls
│   ├── networking/             # VNet and NSG controls
│   ├── logging/                # Activity logs and Security Center controls
│   └── data/                   # Storage and database encryption controls
└── common/                     # Multi-cloud common controls (future use)
```

## Control System Overview

### Control ID System

Controls follow a structured naming convention:
- **AWS Controls**: `{DOMAIN}-{NUMBER}` (e.g., `IAM-001`, `NET-001`)
- **Azure Controls**: `AZ-{DOMAIN}-{NUMBER}` (e.g., `AZ-IAM-001`, `AZ-NET-001`)

### Domains
- **Identity**: IAM, RBAC, authentication, and authorization controls
- **Networking**: VPC, VNet, security groups, and network access controls
- **Logging**: Audit logging, monitoring, and compliance logging controls
- **Data**: Encryption, data protection, and storage security controls

### Severity Levels
- **CRITICAL**: Immediate security risk, must be addressed
- **HIGH**: Significant security risk, should be addressed promptly
- **MEDIUM**: Moderate security risk, should be addressed in planned maintenance
- **LOW**: Minor security risk, can be addressed when convenient

## Framework Mappings

Each control is mapped to relevant compliance frameworks:

### NIST SP 800-53 Security Controls
- **AC**: Access Control
- **AU**: Audit and Accountability
- **CM**: Configuration Management
- **CP**: Contingency Planning
- **IA**: Identification and Authentication
- **IR**: Incident Response
- **SC**: System and Communications Protection
- **SI**: System and Information Integrity

### CIS Benchmarks
- **CIS-AWS**: CIS Amazon Web Services Foundations Benchmark
- **CIS-Azure**: CIS Microsoft Azure Foundations Benchmark

### ISO/IEC 27001 Annex A Controls
- **A.9**: Access Control
- **A.10**: Cryptography
- **A.12**: Operations Security
- **A.13**: Communications Security
- **A.16**: Information Security Incident Management

## Control Structure

Each control is implemented as a Rego policy with the following structure:

```rego
# CONTROL: {CONTROL_ID}
# TITLE: {Control Title}
# SEVERITY: {CRITICAL|HIGH|MEDIUM|LOW}
# FRAMEWORKS: {Framework mappings}
# STATUS: ENABLED

package terraform.security.{cloud}.{domain}.{policy_name}

import rego.v1

deny contains msg if {
    # Control logic here
    
    msg := {
        "control_id": "{CONTROL_ID}",
        "severity": "{SEVERITY}",
        "resource": resource.address,
        "message": "{Violation message}",
        "remediation": "{Remediation guidance}"
    }
}
```

## Enabling/Disabling Controls

Controls can be enabled or disabled by commenting/uncommenting the control blocks:

### To Disable a Control
```rego
# CONTROL: IAM-001 (DISABLED)
# deny contains msg if {
#     # Control logic here
# }
```

### To Enable a Control
```rego
# CONTROL: IAM-001 (ENABLED)
deny contains msg if {
    # Control logic here
}
```

## Usage with Conftest

These policies are designed to work with Conftest for policy evaluation:

```bash
# Evaluate all policies against a Terraform plan
conftest test --policy policies/ terraform_plan.json

# Evaluate specific domain policies
conftest test --policy policies/aws/identity/ terraform_plan.json

# Evaluate with specific output format
conftest test --policy policies/ --output json terraform_plan.json
```

## Adding New Controls

When adding new controls:

1. **Choose appropriate domain and cloud provider**
2. **Follow the naming convention**
3. **Include all required metadata in comments**
4. **Map to at least one compliance framework**
5. **Assign appropriate severity level**
6. **Provide clear remediation guidance**
7. **Update the control catalog and metadata files**
8. **Test with positive and negative test cases**

### Example New Control

```rego
# CONTROL: IAM-007
# TITLE: IAM users must not have console access without MFA
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:IA-2, CIS-AWS:1.2, ISO-27001:A.9.4.2
# STATUS: ENABLED

package terraform.security.aws.identity.console_access

import rego.v1

deny contains msg if {
    # Control implementation
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_user_login_profile"
    
    # Check for MFA requirement
    not has_mfa_requirement(resource.values.user)
    
    msg := {
        "control_id": "IAM-007",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "IAM user has console access but MFA is not enforced",
        "remediation": "Enable MFA enforcement for console access"
    }
}
```

## Control Testing

Each control should have corresponding test cases:

### Positive Test Cases
Test cases that should pass the control (no violations)

### Negative Test Cases  
Test cases that should fail the control (trigger violations)

### Test Organization
```
tests/
├── aws/
│   ├── identity/
│   │   ├── iam_policies_test.rego
│   │   └── mfa_requirements_test.rego
│   └── ...
└── azure/
    └── ...
```

## Compliance Matrix Export

Use the provided script to export compliance matrices:

```bash
# Export both CSV and JSON formats
./scripts/export-compliance-matrix.sh

# Export only CSV format
./scripts/export-compliance-matrix.sh --format csv

# Export to specific directory
./scripts/export-compliance-matrix.sh --output /path/to/output
```

## Integration with CI/CD

These policies integrate with CI/CD pipelines through the main scan script:

```bash
# Run policy evaluation in CI
./scripts/scan.sh --terraform-dir ./infrastructure --output-format json
```

## Maintenance

### Regular Updates
- Review and update framework mappings as standards evolve
- Add new controls for emerging security requirements
- Update existing controls based on cloud provider changes

### Version Control
- All control changes should be tracked in version control
- Use semantic versioning for control catalog releases
- Document breaking changes in control behavior

## Support

For questions about specific controls or adding new controls, refer to:
- [Control Catalog](CONTROL_CATALOG.md) for detailed control documentation
- [Contributing Guide](../CONTRIBUTING.md) for contribution guidelines
- [Security Policy](../SECURITY.md) for security-related issues