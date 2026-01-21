# Controls Selection Guide

This guide helps you select and enable optional security controls based on your organization's security requirements, compliance needs, and operational constraints.

## Quick Start

### 1. Assess Your Environment
Before enabling optional controls, evaluate:
- **Security Maturity**: Current security practices and capabilities
- **Compliance Requirements**: Regulatory frameworks you must meet
- **Operational Impact**: How controls will affect daily operations
- **Technical Readiness**: Infrastructure and tooling capabilities

### 2. Review Available Controls
```bash
# List all optional controls (currently disabled)
./scripts/list-controls.sh --status disabled

# View detailed information about specific controls
./scripts/toggle-control.sh status OPT-AWS-IAM-001
```

### 3. Enable Controls Gradually
```bash
# Enable a single control
./scripts/toggle-control.sh enable OPT-AWS-IAM-001

# Test the control with a Terraform plan
terraform plan | ./scripts/run-conftest.sh

# If successful, commit the change
git add policies/
git commit -m "Enable OPT-AWS-IAM-001: Require MFA for all API access"
```

## Control Categories and Selection Criteria

### Identity & Access Management Controls

#### AWS IAM Controls

**OPT-AWS-IAM-001: Require MFA for all API access**
- **When to Enable**: High-security environments, compliance requirements
- **Prerequisites**: MFA devices configured for all users
- **Impact**: May break automated processes without MFA support
- **Recommended For**: Production environments, financial services, healthcare

**OPT-AWS-IAM-002: Enforce strict password complexity**
- **When to Enable**: Regulatory compliance, high-security requirements
- **Prerequisites**: User training on new password requirements
- **Impact**: Users may need to change existing passwords
- **Recommended For**: Organizations with strict password policies

**OPT-AWS-IAM-003: Require IAM role session duration limits**
- **When to Enable**: Zero-trust security model, compliance requirements
- **Prerequisites**: Applications must handle session renewal
- **Impact**: May require application changes for shorter sessions
- **Recommended For**: Environments with sensitive data access

**OPT-AWS-IAM-004: Require explicit deny for sensitive actions**
- **When to Enable**: Defense-in-depth strategy, compliance requirements
- **Prerequisites**: Review all existing policies for compatibility
- **Impact**: May break existing workflows relying on implicit permissions
- **Recommended For**: Highly regulated environments

#### Azure Identity Controls

**OPT-AZ-IAM-001: Require Conditional Access for administrative roles**
- **When to Enable**: Zero-trust security model, compliance requirements
- **Prerequisites**: Azure AD Premium P1/P2, Conditional Access policies configured
- **Impact**: May block admin access if not properly configured
- **Recommended For**: Organizations with Azure AD Premium licensing

**OPT-AZ-IAM-002: Enforce PIM for privileged access**
- **When to Enable**: Just-in-time access requirements, compliance
- **Prerequisites**: Azure AD Premium P2, PIM configuration
- **Impact**: Changes privileged access workflow significantly
- **Recommended For**: Large organizations, high-security environments

**OPT-AZ-IAM-003: Require certificate-based authentication**
- **When to Enable**: Enhanced security for service principals
- **Prerequisites**: Certificate management infrastructure
- **Impact**: Requires migration from password-based authentication
- **Recommended For**: Production environments, automated systems

**OPT-AZ-IAM-004: Enforce break-glass account monitoring**
- **When to Enable**: Compliance requirements, security monitoring
- **Prerequisites**: Azure Monitor, alerting infrastructure
- **Impact**: Requires additional monitoring configuration
- **Recommended For**: All environments with break-glass accounts

**OPT-AZ-IAM-005: Require JIT access for VM administration**
- **When to Enable**: Zero-trust network access, compliance
- **Prerequisites**: Azure Security Center Standard tier
- **Impact**: Changes VM access workflow
- **Recommended For**: Production environments, sensitive workloads

## Selection Framework

### Risk-Based Selection

#### High-Risk Environments
Enable controls that provide maximum security:
- All MFA-related controls
- Session duration limits
- Explicit deny policies
- JIT access controls

#### Medium-Risk Environments
Balance security and operational efficiency:
- Password complexity controls
- Conditional Access for admin roles
- Certificate-based authentication
- Monitoring and alerting controls

#### Low-Risk Environments
Focus on foundational security:
- Basic MFA requirements
- Monitoring controls
- Gradual implementation of stricter controls

### Compliance-Based Selection

#### SOC 2 Type II
Required controls:
- MFA for administrative access
- Session management controls
- Access monitoring and logging
- Privileged access management

#### PCI DSS
Required controls:
- Strong authentication mechanisms
- Access control restrictions
- Monitoring and logging
- Regular access reviews

#### HIPAA
Required controls:
- Multi-factor authentication
- Access controls for PHI
- Audit logging and monitoring
- Minimum necessary access

#### FedRAMP
Required controls:
- All identity and access controls
- Strict session management
- Comprehensive monitoring
- Defense-in-depth measures

### Industry-Specific Recommendations

#### Financial Services
- Enable all MFA controls
- Implement strict session limits
- Require explicit deny policies
- Enable comprehensive monitoring

#### Healthcare
- Focus on access controls for PHI
- Implement audit logging
- Enable break-glass monitoring
- Require strong authentication

#### Government
- Enable all available controls
- Implement defense-in-depth
- Require certificate-based authentication
- Enable comprehensive monitoring

#### Technology Companies
- Balance security with development velocity
- Enable monitoring controls
- Implement JIT access
- Gradual rollout of strict controls

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
1. **Assessment**
   - Review current security posture
   - Identify compliance requirements
   - Assess technical readiness

2. **Planning**
   - Select initial controls to enable
   - Plan testing and rollout strategy
   - Prepare documentation and training

### Phase 2: Low-Impact Controls (Weeks 3-4)
1. **Enable Monitoring Controls**
   - Break-glass account monitoring
   - Access logging enhancements
   - Alert configuration

2. **Test and Validate**
   - Verify controls work as expected
   - Monitor for operational impact
   - Adjust configurations as needed

### Phase 3: Medium-Impact Controls (Weeks 5-8)
1. **Enable Authentication Controls**
   - Enhanced password policies
   - Certificate-based authentication
   - Conditional Access policies

2. **Gradual Rollout**
   - Start with non-production environments
   - Monitor user feedback and issues
   - Provide training and support

### Phase 4: High-Impact Controls (Weeks 9-12)
1. **Enable Strict Access Controls**
   - MFA requirements
   - Session duration limits
   - JIT access controls

2. **Full Production Deployment**
   - Roll out to production environments
   - Monitor for issues and performance impact
   - Document lessons learned

### Phase 5: Optimization (Ongoing)
1. **Continuous Improvement**
   - Regular review of control effectiveness
   - Adjustment based on operational feedback
   - Addition of new controls as needed

2. **Maintenance**
   - Regular testing of controls
   - Updates for new threats and requirements
   - Training and awareness programs

## Testing and Validation

### Pre-Enablement Testing
```bash
# Test control syntax
./scripts/validate-policies.sh policies/optional/

# Test with sample Terraform plan
terraform plan -out=test.tfplan
terraform show -json test.tfplan | ./scripts/run-conftest.sh --policy policies/optional/
```

### Post-Enablement Validation
```bash
# Verify control is enabled
./scripts/toggle-control.sh status OPT-AWS-IAM-001

# Test with real infrastructure
terraform plan | ./scripts/run-conftest.sh

# Monitor for violations
./scripts/generate-report.sh --severity high
```

### Rollback Procedures
```bash
# Disable problematic control
./scripts/toggle-control.sh disable OPT-AWS-IAM-001

# Verify control is disabled
./scripts/toggle-control.sh status OPT-AWS-IAM-001

# Test that issues are resolved
terraform plan | ./scripts/run-conftest.sh
```

## Troubleshooting Common Issues

### Control Not Working After Enabling
1. **Check Syntax**: Verify Rego syntax is correct
2. **Validate Logic**: Ensure control logic matches your infrastructure
3. **Test Isolation**: Test control with minimal Terraform configuration
4. **Review Logs**: Check policy evaluation logs for errors

### Operational Impact Issues
1. **Gradual Rollout**: Enable controls in stages
2. **User Training**: Provide training on new requirements
3. **Exception Handling**: Plan for legitimate exceptions
4. **Monitoring**: Monitor for unexpected impacts

### Performance Issues
1. **Control Optimization**: Review and optimize control logic
2. **Scope Limitation**: Limit control scope if needed
3. **Batch Processing**: Process policy evaluations in batches
4. **Resource Monitoring**: Monitor system resources during evaluation

## Best Practices

### Control Management
- **Version Control**: Always use version control for control changes
- **Testing**: Test controls thoroughly before production deployment
- **Documentation**: Document all enabled controls and their purpose
- **Review**: Regularly review and update enabled controls

### Operational Excellence
- **Monitoring**: Monitor control effectiveness and operational impact
- **Training**: Provide ongoing training on security controls
- **Communication**: Communicate control changes to affected teams
- **Feedback**: Collect and act on feedback from users

### Security Considerations
- **Defense in Depth**: Use controls as part of layered security
- **Risk Assessment**: Base control selection on risk assessment
- **Threat Modeling**: Consider controls in context of threat model
- **Incident Response**: Plan how controls affect incident response

## Getting Help

### Internal Resources
- Security team for control selection guidance
- DevOps team for implementation support
- Compliance team for regulatory requirements
- Application teams for impact assessment

### External Resources
- Cloud provider documentation and best practices
- Industry security frameworks and guidelines
- Security community forums and discussions
- Professional security consultants if needed

### Emergency Procedures
- Contact information for security team
- Escalation procedures for control issues
- Emergency disable procedures
- Incident response contacts and procedures