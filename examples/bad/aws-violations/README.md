# AWS Security Violations Example

This example demonstrates common AWS security misconfigurations that trigger policy violations. **DO NOT USE IN PRODUCTION** - these configurations are intentionally insecure for testing and training purposes.

## ⚠️ Security Issues Demonstrated

### Identity & Access Management Violations
- **IAM-001**: Wildcard actions (*) on all resources (*)
- **IAM-002**: Inline policies attached directly to users
- **IAM-003**: Trust policies allowing any principal (*)
- **IAM-004**: Access keys created for root user

### Networking Violations
- **NET-001**: SSH (port 22) access from 0.0.0.0/0
- **NET-002**: RDP (port 3389) access from 0.0.0.0/0
- **NET-003**: Default security group with ingress/egress rules
- **NET-004**: Unrestricted outbound traffic to 0.0.0.0/0

### Data Protection Violations
- **DATA-001**: S3 buckets without server-side encryption
- **DATA-002**: S3 buckets allowing public access
- **DATA-003**: S3 buckets without versioning
- **DATA-004**: S3 buckets without access logging

## Expected Policy Violations

When running policy validation against this configuration, you should see:

```
CRITICAL violations: 6
HIGH violations: 4
MEDIUM violations: 2
LOW violations: 0
```

### Critical Violations
1. IAM policy allows wildcard actions on all resources
2. Root user access key created
3. SSH access from 0.0.0.0/0
4. RDP access from 0.0.0.0/0
5. S3 bucket allows public access
6. IAM role trust policy allows any principal

### High Violations
1. IAM user has inline policy
2. S3 bucket without encryption
3. Default security group has rules
4. Unrestricted outbound traffic

### Medium Violations
1. S3 bucket without versioning
2. S3 bucket without access logging

## Usage for Testing

```bash
# Test that this configuration triggers violations
TERRAFORM_DIR=examples/bad/aws-violations make scan

# Expected result: Multiple violations detected
# Exit code: 1 (failure due to violations)
```

## Educational Value

This example helps:
- **Security Teams**: Validate that policies catch real security issues
- **Developers**: Learn what NOT to do in AWS configurations
- **DevOps Engineers**: Understand common security pitfalls
- **Compliance Officers**: See how violations are detected and reported

## Remediation

For each violation, refer to the corresponding good example in `examples/good/aws-basic/` to see the secure configuration pattern.

## ⚠️ Important Notes

- **Never deploy this configuration to production**
- **Use only for testing and training purposes**
- **All violations are intentional for demonstration**
- **This configuration may incur AWS charges if deployed**