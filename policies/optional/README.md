# Optional Security Controls

This directory contains optional security controls that are disabled by default. These controls can be enabled by uncommenting their code blocks using the control toggle scripts.

## Overview

Optional controls are security policies that may not be suitable for all environments or may require additional configuration before deployment. They are provided as commented-out code blocks that can be selectively enabled based on your organization's security requirements and operational constraints.

## Control Categories

### Strict Compliance Controls
Controls that enforce very strict security policies that may impact operational flexibility:
- Enhanced encryption requirements
- Restrictive network access policies
- Advanced logging and monitoring requirements

### Environment-Specific Controls
Controls that are only applicable to certain environments or use cases:
- Development environment restrictions
- Production-only security measures
- Industry-specific compliance requirements

### Experimental Controls
Controls that are under development or testing:
- New security features
- Beta policy implementations
- Proof-of-concept security measures

## Enabling Optional Controls

### Using the Toggle Script
```bash
# List all optional controls
./scripts/list-controls.sh --status disabled

# Enable a specific optional control
./scripts/toggle-control.sh enable OPT-001

# Check control status
./scripts/toggle-control.sh status OPT-001
```

### Manual Enabling
1. Locate the control block in the appropriate policy file
2. Remove the `#` comment markers from the control code (not the metadata comments)
3. Test the policy to ensure it works correctly
4. Commit the changes to version control

## Control Selection Guide

### Before Enabling Optional Controls

1. **Assess Impact**: Understand how the control will affect your infrastructure and operations
2. **Test in Non-Production**: Enable controls in development/test environments first
3. **Review Dependencies**: Ensure required resources and configurations are in place
4. **Plan Rollback**: Have a plan to disable the control if issues arise

### Recommended Enabling Process

1. **Review Control Documentation**: Read the control description, requirements, and remediation guidance
2. **Check Framework Mappings**: Verify if the control is required for your compliance frameworks
3. **Validate Prerequisites**: Ensure your infrastructure supports the control requirements
4. **Enable in Stages**: Roll out controls gradually across environments
5. **Monitor Results**: Watch for policy violations and operational impacts

## Control Block Structure

Optional controls follow the same structure as regular controls but are commented out by default:

```rego
# CONTROL: OPT-001
# TITLE: Example Optional Control
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-1, CIS-AWS:1.1, ISO-27001:A.9.1.1
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Requires specific IAM configuration
# IMPACT: May affect application deployment workflows

# package terraform.security.aws.optional.example
# 
# import rego.v1
# 
# deny contains msg if {
#     # Control logic here
#     msg := {
#         "control_id": "OPT-001",
#         "severity": "MEDIUM",
#         "resource": "example",
#         "message": "Example violation message",
#         "remediation": "Example remediation guidance"
#     }
# }
```

## Available Optional Controls

### AWS Optional Controls

#### Identity & Access Management
- **OPT-AWS-IAM-001**: Require MFA for all API access
- **OPT-AWS-IAM-002**: Enforce password complexity beyond baseline
- **OPT-AWS-IAM-003**: Require IAM role session duration limits

#### Networking
- **OPT-AWS-NET-001**: Require VPC endpoints for all AWS services
- **OPT-AWS-NET-002**: Enforce private subnets for all compute resources
- **OPT-AWS-NET-003**: Require Network Load Balancer for all public services

#### Data Protection
- **OPT-AWS-DATA-001**: Require customer-managed KMS keys for all encryption
- **OPT-AWS-DATA-002**: Enforce S3 bucket notifications for all access
- **OPT-AWS-DATA-003**: Require RDS encryption with specific key rotation

#### Logging & Monitoring
- **OPT-AWS-LOG-001**: Require CloudWatch Insights for all log groups
- **OPT-AWS-LOG-002**: Enforce GuardDuty findings export to SIEM
- **OPT-AWS-LOG-003**: Require custom CloudTrail event filtering

### Azure Optional Controls

#### Identity & Access Management
- **OPT-AZ-IAM-001**: Require Conditional Access for all admin roles
- **OPT-AZ-IAM-002**: Enforce PIM for all privileged access
- **OPT-AZ-IAM-003**: Require certificate-based authentication

#### Networking
- **OPT-AZ-NET-001**: Require Private Endpoints for all PaaS services
- **OPT-AZ-NET-002**: Enforce Application Gateway for all web applications
- **OPT-AZ-NET-003**: Require Network Security Group flow logs retention

#### Data Protection
- **OPT-AZ-DATA-001**: Require customer-managed keys for all storage
- **OPT-AZ-DATA-002**: Enforce Always Encrypted for SQL databases
- **OPT-AZ-DATA-003**: Require Key Vault private endpoints

#### Logging & Monitoring
- **OPT-AZ-LOG-001**: Require Sentinel integration for all security logs
- **OPT-AZ-LOG-002**: Enforce Defender for Cloud enhanced features
- **OPT-AZ-LOG-003**: Require custom alert rules for all resources

## Best Practices

### Control Management
- **Version Control**: Always commit control changes with descriptive messages
- **Documentation**: Update this README when adding new optional controls
- **Testing**: Test controls in isolated environments before production deployment
- **Monitoring**: Monitor policy evaluation results after enabling controls

### Operational Considerations
- **Performance**: Some controls may impact Terraform plan/apply performance
- **Complexity**: More controls increase policy evaluation complexity
- **Maintenance**: Regular review and updates of optional controls is recommended
- **Training**: Ensure team members understand enabled controls and their implications

### Security Considerations
- **Defense in Depth**: Use optional controls to implement layered security
- **Risk Assessment**: Enable controls based on risk assessment and threat modeling
- **Compliance**: Align optional controls with regulatory and compliance requirements
- **Incident Response**: Consider how controls affect incident response procedures

## Troubleshooting

### Common Issues

#### Control Not Working After Enabling
1. Check for syntax errors in the policy file
2. Verify all required resources are defined in Terraform
3. Ensure control logic matches your infrastructure patterns
4. Test with a simple Terraform plan to isolate issues

#### Policy Evaluation Errors
1. Validate Rego syntax using `opa fmt` or `conftest verify`
2. Check for missing imports or package declarations
3. Verify input data structure matches control expectations
4. Review error messages for specific line numbers and issues

#### Performance Issues
1. Review control logic for efficiency
2. Consider limiting control scope to specific resource types
3. Monitor policy evaluation time and optimize as needed
4. Disable problematic controls temporarily if needed

### Getting Help

1. **Documentation**: Review control-specific documentation and examples
2. **Testing**: Use the test framework to validate control behavior
3. **Community**: Consult with security and DevOps teams
4. **Support**: Contact system administrators for infrastructure-specific issues

## Contributing

When adding new optional controls:

1. Follow the established control block structure
2. Include comprehensive metadata and documentation
3. Provide clear prerequisites and impact descriptions
4. Add appropriate test cases for positive and negative scenarios
5. Update this README with control information
6. Submit changes through the standard review process

## Changelog

- **v1.0.0**: Initial optional controls framework
- **v1.1.0**: Added AWS and Azure optional control templates
- **v1.2.0**: Enhanced documentation and troubleshooting guide