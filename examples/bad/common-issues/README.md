# Common Security Issues Example

This example demonstrates common security misconfigurations that occur across different cloud providers and resource types. These are real-world patterns that often lead to security incidents.

## ⚠️ Common Security Anti-Patterns

### 1. Overprivileged Access
- **Root/Admin Credentials**: Using root or administrative accounts for daily operations
- **Wildcard Permissions**: Granting (*) permissions instead of specific actions
- **Broad Scope**: Assigning permissions at subscription/account level instead of resource level

### 2. Network Exposure
- **Default Allow**: Leaving default "allow all" rules in place
- **Management Ports**: Exposing SSH/RDP to the internet
- **Database Ports**: Making databases directly accessible from the internet
- **No Segmentation**: Flat network architecture without proper isolation

### 3. Data Exposure
- **Public Storage**: Making storage buckets/containers publicly accessible
- **Unencrypted Data**: Not enabling encryption at rest or in transit
- **No Access Logging**: Missing audit trails for data access
- **Weak TLS**: Using outdated TLS versions

### 4. Credential Management
- **Hardcoded Secrets**: Embedding credentials in code or configuration
- **Long-lived Credentials**: Using permanent access keys instead of temporary tokens
- **No Rotation**: Never rotating credentials or certificates
- **Shared Accounts**: Multiple people using the same credentials

### 5. Monitoring Gaps
- **No Logging**: Disabling or not configuring security logging
- **No Alerting**: Missing alerts for security events
- **No Compliance**: Not monitoring for compliance violations
- **No Incident Response**: No automated response to security events

## Real-World Impact Examples

### Data Breaches
```
Misconfiguration: S3 bucket with public read access
Impact: Customer PII exposed to the internet
Cost: $2.8M in fines and remediation
```

### Cryptojacking
```
Misconfiguration: SSH open to 0.0.0.0/0 with weak passwords
Impact: Servers compromised for cryptocurrency mining
Cost: $50K in compute charges and downtime
```

### Privilege Escalation
```
Misconfiguration: IAM role with wildcard permissions
Impact: Lateral movement across entire AWS account
Cost: Complete environment rebuild required
```

### Compliance Violations
```
Misconfiguration: Database without encryption
Impact: Failed SOC 2 audit
Cost: Lost customer contracts worth $500K
```

## Detection and Prevention

### Policy as Code
- Implement automated policy validation in CI/CD pipelines
- Use tools like OPA/Conftest to catch misconfigurations early
- Require policy approval for infrastructure changes

### Least Privilege
- Start with minimal permissions and add as needed
- Use resource-specific roles instead of broad permissions
- Implement just-in-time access for administrative tasks

### Defense in Depth
- Multiple layers of security controls
- Network segmentation with security groups/NSGs
- Encryption at rest and in transit
- Comprehensive logging and monitoring

### Security by Default
- Use secure baselines and templates
- Enable security features by default
- Require explicit approval to disable security controls

## Testing This Configuration

```bash
# This example intentionally contains multiple violations
TERRAFORM_DIR=examples/bad/common-issues make scan

# Expected: High number of violations across all categories
```

## Learning Resources

- [OWASP Cloud Security](https://owasp.org/www-project-cloud-security/)
- [CIS Controls](https://www.cisecurity.org/controls/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [Cloud Security Alliance](https://cloudsecurityalliance.org/)

## ⚠️ Important Reminder

These configurations represent real security risks. Understanding these patterns helps:
- **Security Engineers**: Recognize and prevent common mistakes
- **Developers**: Build security awareness and best practices
- **Operations Teams**: Implement proper monitoring and response procedures
- **Management**: Understand the business impact of security misconfigurations