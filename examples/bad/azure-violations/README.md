# Azure Security Violations Example

This example demonstrates common Azure security misconfigurations that trigger policy violations. **DO NOT USE IN PRODUCTION** - these configurations are intentionally insecure for testing and training purposes.

## ⚠️ Security Issues Demonstrated

### Identity & Access Management Violations
- **AZ-IAM-001**: Custom RBAC roles with wildcard permissions (*)
- **AZ-IAM-002**: Owner role assignments at subscription scope
- **AZ-IAM-003**: Service principal credentials without expiration dates
- **AZ-IAM-005**: Privileged role assignments without MFA documentation

### Networking Violations
- **AZ-NET-001**: SSH (port 22) access from any source (*)
- **AZ-NET-002**: RDP (port 3389) access from any source (*)
- **AZ-NET-003**: Unrestricted inbound access (all ports from *)
- **AZ-NET-004**: NSGs with no custom security rules
- **AZ-NET-005**: High-risk ports accessible from any source

### Data Protection Violations
- **AZ-DATA-001**: Storage accounts not enforcing HTTPS-only traffic
- **AZ-DATA-002**: Storage accounts allowing public blob access
- **AZ-DATA-003**: Storage containers with public access types
- **AZ-DATA-005**: Storage accounts with TLS version below 1.2
- **AZ-DATA-006**: Storage accounts without blob soft delete

## Expected Policy Violations

When running policy validation against this configuration, you should see:

```
CRITICAL violations: 4
HIGH violations: 5
MEDIUM violations: 3
LOW violations: 0
```

### Critical Violations
1. Custom RBAC role allows wildcard actions (*)
2. SSH access from any source (*)
3. RDP access from any source (*)
4. Storage container allows public access

### High Violations
1. Owner role assigned at subscription scope
2. Unrestricted inbound access to all ports
3. High-risk ports accessible from anywhere
4. Storage account not enforcing HTTPS-only
5. Storage account TLS version below 1.2

### Medium Violations
1. Service principal without credential expiration
2. NSG with no custom rules
3. Storage account without blob soft delete

## Usage for Testing

```bash
# Test that this configuration triggers violations
TERRAFORM_DIR=examples/bad/azure-violations make scan

# Expected result: Multiple violations detected
# Exit code: 1 (failure due to violations)
```

## Educational Value

This example helps:
- **Security Teams**: Validate that policies catch real security issues
- **Developers**: Learn what NOT to do in Azure configurations
- **DevOps Engineers**: Understand common security pitfalls
- **Compliance Officers**: See how violations are detected and reported

## Remediation

For each violation, refer to the corresponding good example in `examples/good/azure-basic/` to see the secure configuration pattern.

## ⚠️ Important Notes

- **Never deploy this configuration to production**
- **Use only for testing and training purposes**
- **All violations are intentional for demonstration**
- **This configuration may incur Azure charges if deployed**
- **Some violations may require subscription-level permissions to test**