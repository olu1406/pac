# Frequently Asked Questions (FAQ)

## General Questions

### What is the Multi-Cloud Security Policy System?

The Multi-Cloud Security Policy System is a comprehensive policy-as-code solution that provides:
- Secure-by-default Terraform landing zone modules for AWS and Azure
- Policy guardrails that validate Terraform plans before deployment
- Framework-mapped security controls (NIST 800-53, ISO 27001, CIS)
- Comprehensive reporting and compliance evidence generation

### How does it differ from other security scanning tools?

Key differences:
- **Prevention-focused**: Catches issues at plan-time, not after deployment
- **Multi-cloud native**: Built specifically for AWS and Azure with unified policies
- **Framework-mapped**: Controls directly map to compliance frameworks
- **Developer-friendly**: Simple comment/uncomment control management
- **Landing zone integrated**: Includes secure infrastructure baselines

### Do I need cloud credentials to use this system?

No, for basic policy validation you can run scans without cloud credentials. The system works by analyzing Terraform plan JSON files, which can be generated offline. Cloud credentials are only needed if you want to:
- Deploy the landing zone modules
- Validate against live cloud resources
- Use cloud-specific data sources in policies

## Installation and Setup

### What are the minimum system requirements?

- **Operating System**: Linux, macOS, or Windows with WSL
- **Memory**: 2GB RAM minimum, 4GB recommended for large infrastructures
- **Disk Space**: 1GB for tools and dependencies
- **Network**: Internet access for tool downloads and Terraform providers

### Can I use this with existing Terraform configurations?

Yes! The system is designed to work with existing Terraform configurations. You can:
- Scan existing infrastructure code without modifications
- Gradually adopt the landing zone modules
- Customize policies to match your existing standards
- Integrate with existing CI/CD pipelines

### How do I integrate with my existing CI/CD pipeline?

The system provides examples for popular CI/CD platforms:
- **GitHub Actions**: Pre-built workflow files
- **GitLab CI**: Pipeline configuration examples
- **Jenkins**: Pipeline script examples
- **Azure DevOps**: Task configurations

Integration typically involves:
1. Installing dependencies in your CI environment
2. Running the scan script as part of your pipeline
3. Storing reports as artifacts
4. Failing builds on policy violations

## Policy Management

### How do I enable or disable specific controls?

Controls are managed through a simple comment/uncomment system:

```rego
# To disable a control, comment out the entire rule block:
# deny[msg] {
#     condition
#     msg := "Violation message"
# }

# To enable a control, uncomment the rule block:
deny[msg] {
    condition
    msg := "Violation message"
}
```

Use the provided scripts for bulk operations:
```bash
# List all controls and their status
./scripts/list-controls.sh

# Enable a specific control
./scripts/toggle-control.sh --enable NET-001

# Disable a specific control
./scripts/toggle-control.sh --disable NET-001
```

### Can I create custom policies?

Yes! The system is designed for extensibility:

1. **Create new policy files** in the appropriate directory structure
2. **Follow the established patterns** for control metadata and structure
3. **Add test cases** for both positive and negative scenarios
4. **Update the control catalog** with framework mappings

Use the scaffolding script to get started:
```bash
./scripts/new-control.sh --cloud aws --domain networking --id NET-010
```

### How do I map controls to different compliance frameworks?

Controls include framework mappings in their metadata:

```rego
# CONTROL: NET-001
# TITLE: No public SSH access from 0.0.0.0/0
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.1, ISO-27001:A.13.1.1
```

To add new framework mappings:
1. Update the control metadata in policy files
2. Update the control catalog documentation
3. Regenerate compliance matrices

### What happens if a policy has syntax errors?

The system includes comprehensive validation:
- **Pre-commit validation**: Syntax checking before code commits
- **CI validation**: Automated syntax checking in pipelines
- **Runtime validation**: Error reporting during scans

Syntax errors are reported with:
- File name and line number
- Specific error description
- Suggested fixes when possible

## Scanning and Reports

### How long does a typical scan take?

Scan duration depends on several factors:
- **Infrastructure size**: Number of resources in Terraform plan
- **Policy count**: Number of enabled policies
- **System resources**: Available CPU and memory

Typical scan times:
- **Small infrastructure** (< 50 resources): 10-30 seconds
- **Medium infrastructure** (50-200 resources): 30-90 seconds
- **Large infrastructure** (200+ resources): 2-5 minutes

### What output formats are available?

The system supports multiple output formats:
- **JSON**: Machine-readable format for automation
- **Markdown**: Human-readable format for documentation
- **CSV**: Compliance matrices for spreadsheet analysis
- **HTML**: Web-friendly format for dashboards

### How do I filter scan results?

Multiple filtering options are available:

```bash
# Filter by severity
./scripts/scan.sh --severity high

# Filter by specific controls
./scripts/scan.sh --controls "NET-001,IAM-002"

# Exclude specific controls
./scripts/scan.sh --exclude-controls "OPT-001"

# Filter by cloud provider
./scripts/scan.sh --cloud aws

# Filter by domain
./scripts/scan.sh --domain networking
```

### Can I scan multiple environments with different settings?

Yes! The system supports environment-specific configurations:

```bash
# Scan with development settings (relaxed)
./scripts/scan.sh --environment dev

# Scan with production settings (strict)
./scripts/scan.sh --environment prod

# Use custom configuration
./scripts/scan.sh --config ./custom-config.yaml
```

Environment configurations are stored in `config/environments/` and can be customized for your needs.

## Landing Zone Modules

### What's included in the AWS landing zone module?

The AWS landing zone module provides:
- **Organization setup**: Multi-account structure with OUs
- **IAM baselines**: Secure roles, policies, and permission boundaries
- **Security services**: CloudTrail, Config, GuardDuty, Security Hub
- **Networking**: Secure VPC with proper segmentation
- **Monitoring**: CloudWatch, flow logs, and alerting

### What's included in the Azure landing zone module?

The Azure landing zone module provides:
- **Management groups**: Hierarchical organization structure
- **RBAC baselines**: Secure role assignments and PIM integration
- **Security services**: Defender for Cloud, Azure Policy, Sentinel
- **Networking**: Secure VNet with NSG baselines
- **Monitoring**: Log Analytics, activity logs, and alerting

### Can I use only parts of the landing zone modules?

Yes! The modules are designed to be modular:
- Use individual components (e.g., just networking)
- Customize variables to disable unwanted features
- Override defaults with your own configurations
- Gradually adopt components over time

### How do I customize the landing zone for my organization?

Customization options include:
- **Variable overrides**: Modify behavior through input variables
- **Environment-specific configs**: Different settings per environment
- **Module composition**: Combine modules in different ways
- **Policy customization**: Enable/disable specific controls

## Compliance and Frameworks

### Which compliance frameworks are supported?

Currently supported frameworks:
- **NIST 800-53**: Comprehensive security controls
- **ISO/IEC 27001**: Information security management
- **CIS Controls**: Center for Internet Security benchmarks
- **AWS Well-Architected**: AWS security pillar
- **Azure Security Benchmark**: Microsoft security recommendations

Additional frameworks can be added by updating control metadata.

### How do I generate compliance reports?

Use the compliance export functionality:

```bash
# Generate compliance matrix for all frameworks
./scripts/export-compliance.sh --format csv

# Generate for specific framework
./scripts/export-compliance.sh --framework nist-800-53

# Include control status and evidence
./scripts/export-compliance.sh --include-evidence
```

### Can I add custom compliance frameworks?

Yes! To add a new framework:
1. Update control metadata with new framework mappings
2. Add framework definition to `policies/control_metadata.json`
3. Update export scripts to include the new framework
4. Regenerate compliance documentation

## Performance and Scalability

### How does the system handle large Terraform configurations?

Performance optimizations include:
- **Streaming processing**: Handle large plan files without loading entirely into memory
- **Parallel evaluation**: Evaluate multiple policies concurrently
- **Incremental scanning**: Process only changed resources when possible
- **Caching**: Cache compiled policies and intermediate results

### Can I run scans in parallel for multiple projects?

Yes, but consider resource limitations:
- Each scan uses CPU and memory resources
- Terraform state locking may prevent parallel operations
- Use different output directories for each scan
- Monitor system resources to avoid overload

### What are the resource requirements for large infrastructures?

For infrastructures with 1000+ resources:
- **Memory**: 8GB+ RAM recommended
- **CPU**: Multi-core processor for parallel processing
- **Disk**: SSD storage for better I/O performance
- **Network**: Stable connection for provider downloads

## Troubleshooting

### The scan is failing with "command not found" errors

This usually indicates missing dependencies:

```bash
# Check if tools are installed
which terraform conftest opa

# Install missing tools
make install

# Verify PATH includes tool locations
echo $PATH
```

### Policies are not detecting violations I expect to see

Common causes and solutions:
- **Controls disabled**: Check if controls are commented out
- **Wrong resource types**: Verify policy targets correct resources
- **Plan structure**: Ensure Terraform plan includes expected resources
- **Policy logic**: Test policy logic with minimal examples

### Reports are not being generated

Check these common issues:
- **Output directory permissions**: Ensure write access to reports directory
- **Disk space**: Verify sufficient disk space available
- **Output format**: Confirm output format is specified correctly
- **Scan completion**: Ensure scan completes without errors

### How do I get help with specific issues?

1. **Check documentation**: Review docs/ directory for detailed guides
2. **Search existing issues**: Look for similar problems in GitHub issues
3. **Enable debug mode**: Run with `--verbose` flag for detailed output
4. **Create an issue**: Provide system info, error messages, and reproduction steps

## Security Considerations

### Is it safe to run this in production environments?

Yes, with proper precautions:
- **Read-only operations**: Scanning doesn't modify infrastructure
- **Credential security**: Use least-privilege access and secure credential storage
- **Network security**: Ensure secure connections to cloud APIs
- **Audit logging**: Enable logging for security monitoring

### How are credentials handled securely?

Security measures include:
- **No credential storage**: Credentials are never stored in files or logs
- **Standard providers**: Use cloud-native credential providers
- **Least privilege**: Require only read permissions for scanning
- **Audit trails**: Log authentication events for monitoring

### What data is collected or transmitted?

The system:
- **Does not collect**: Personal data, credentials, or sensitive infrastructure details
- **Processes locally**: All scanning happens on your infrastructure
- **Generates reports**: Only violation summaries and metadata
- **No telemetry**: No data is sent to external services

## Contributing and Development

### How can I contribute to the project?

Contributions are welcome! You can:
- **Report bugs**: Create issues for problems you encounter
- **Suggest features**: Propose new functionality or improvements
- **Submit policies**: Contribute new security controls
- **Improve documentation**: Help make docs clearer and more comprehensive
- **Code contributions**: Submit pull requests with fixes or features

See [CONTRIBUTING.md](../CONTRIBUTING.md) for detailed guidelines.

### How do I develop and test new policies?

Development workflow:
1. **Create policy file** using established patterns
2. **Add test cases** for positive and negative scenarios
3. **Test locally** with example configurations
4. **Validate syntax** using provided tools
5. **Submit pull request** with tests and documentation

### Can I use this system as a library in other tools?

The system is designed for modularity:
- **Scripts can be called** from other automation tools
- **JSON output** can be consumed by other systems
- **Policies can be reused** in other OPA-based tools
- **Modules can be referenced** in other Terraform configurations

---

## Still Have Questions?

If your question isn't answered here:
- Check the [documentation](../docs/) for detailed guides
- Search [GitHub Issues](https://github.com/your-repo/issues) for similar questions
- Start a [GitHub Discussion](https://github.com/your-repo/discussions) for community help
- Create a new issue for bugs or feature requests

For security-related questions, follow the guidelines in [SECURITY.md](../SECURITY.md).