# Multi-Cloud Security Policy System

A comprehensive policy-as-code solution for securing Terraform-based infrastructure across AWS and Azure. This system provides secure-by-default landing zone modules and policy guardrails that validate Terraform plans before deployment using Open Policy Agent (OPA) and Conftest.

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Conftest](https://www.conftest.dev/install/) >= 0.30
- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/docs/latest/#running-opa) >= 0.40
- Make (optional, for convenience commands)
- Bash shell (for script execution)

### Installation

#### Option 1: Automated Setup (Recommended)

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd multi-cloud-security-policy
   ```

2. **Run automated setup:**
   ```bash
   make install
   make setup
   ```

3. **Verify installation:**
   ```bash
   make validate
   ```

#### Option 2: Manual Setup

1. **Install Terraform:**
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Install Conftest:**
   ```bash
   # macOS
   brew install conftest
   
   # Linux
   wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
   tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
   sudo mv conftest /usr/local/bin/
   ```

3. **Install OPA:**
   ```bash
   # macOS
   brew install opa
   
   # Linux
   curl -L -o opa https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64_static
   chmod 755 ./opa
   sudo mv opa /usr/local/bin/
   ```

4. **Verify installations:**
   ```bash
   terraform version
   conftest --version
   opa version
   ```

### First Scan - Step by Step

#### 1. Test with Example Configurations

Start by scanning the provided example configurations to ensure everything works:

```bash
# Scan a good example (should pass all checks)
./scripts/scan.sh -d examples/good/aws-basic -o both

# Scan a bad example (should show violations)
./scripts/scan.sh -d examples/bad/aws-violations -o both
```

Expected output for good example:
```
✅ Policy validation completed successfully
📊 Scan Results: 0 violations found
📄 Reports generated: reports/scan-report.json, reports/scan-report.md
```

Expected output for bad example:
```
❌ Policy violations detected
📊 Scan Results: 5 violations found (2 critical, 2 high, 1 medium)
📄 Reports generated: reports/scan-report.json, reports/scan-report.md
```

#### 2. Scan Your Own Infrastructure

```bash
# Navigate to your Terraform directory
cd /path/to/your/terraform

# Generate Terraform plan
terraform init
terraform plan -out=tfplan

# Run security scan
/path/to/multi-cloud-security-policy/scripts/scan.sh -d . -o both
```

#### 3. Review Results

Check the generated reports:
```bash
# View human-readable summary
cat reports/scan-report.md

# View detailed JSON report
jq '.' reports/scan-report.json

# View violations by severity
jq '.violations[] | select(.severity == "CRITICAL")' reports/scan-report.json
```

### Basic Usage Patterns

#### Standard Scanning

```bash
# Scan current directory with default settings
./scripts/scan.sh

# Scan specific Terraform directory
./scripts/scan.sh -d ./infrastructure

# Scan with custom output directory
./scripts/scan.sh -d ./infrastructure -r ./custom-reports

# Generate both JSON and Markdown reports
./scripts/scan.sh -o both

# Generate only JSON report
./scripts/scan.sh -o json
```

#### Filtering and Targeting

```bash
# Filter by severity level (only show high and critical)
./scripts/scan.sh -s high

# Filter by specific control IDs
./scripts/scan.sh --controls "NET-001,IAM-002,LOG-001"

# Exclude specific controls
./scripts/scan.sh --exclude-controls "OPT-001,OPT-002"

# Scan for specific environment
./scripts/scan.sh -e production
```

#### Advanced Options

```bash
# Continue scanning even if violations found
./scripts/scan.sh --continue-on-error

# Verbose output for debugging
./scripts/scan.sh --verbose

# Dry run (validate setup without scanning)
./scripts/scan.sh --dry-run

# Custom configuration file
./scripts/scan.sh -c ./custom-config.yaml
```

### Integration Examples

#### GitHub Actions

```yaml
name: Security Policy Scan
on: [push, pull_request]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
      - name: Install Dependencies
        run: make install
      - name: Run Security Scan
        run: make scan
      - name: Upload Reports
        uses: actions/upload-artifact@v3
        with:
          name: security-reports
          path: reports/
```

#### GitLab CI

```yaml
security-scan:
  stage: test
  image: ubuntu:latest
  before_script:
    - apt-get update && apt-get install -y make wget unzip
    - make install
  script:
    - make scan
  artifacts:
    reports:
      junit: reports/scan-report.xml
    paths:
      - reports/
```

#### Jenkins Pipeline

```groovy
pipeline {
    agent any
    stages {
        stage('Security Scan') {
            steps {
                sh 'make install'
                sh 'make scan'
                publishHTML([
                    allowMissing: false,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'reports',
                    reportFiles: 'scan-report.html',
                    reportName: 'Security Scan Report'
                ])
            }
        }
    }
}

## 📁 Project Structure

```
├── modules/           # Terraform landing zone modules
│   ├── aws/          # AWS secure baseline modules
│   └── azure/        # Azure secure baseline modules
├── policies/         # OPA/Rego security policies
│   ├── aws/          # AWS-specific policies
│   ├── azure/        # Azure-specific policies
│   └── common/       # Multi-cloud policies
├── scripts/          # Automation and utility scripts
│   └── scan.sh       # Main orchestration script
├── examples/         # Example configurations
│   ├── good/         # Compliant examples
│   └── bad/          # Non-compliant examples (for testing)
├── docs/             # Documentation
├── config/           # Configuration files
│   └── environments/ # Environment-specific configs
└── reports/          # Generated scan reports
```

## 🛡️ Features

### Secure Landing Zones
- **AWS Landing Zone**: Secure organization setup, IAM baselines, CloudTrail, Config, GuardDuty
- **Azure Landing Zone**: Management groups, RBAC, Azure Policy, Defender for Cloud
- **Environment Support**: Configurable for dev/test/prod environments
- **Security Baselines**: CIS benchmarks and security best practices built-in

### Policy Guardrails
- **Plan-Time Validation**: Catch security issues before deployment
- **Framework Mapping**: Controls mapped to NIST 800-53, ISO 27001, CIS
- **Flexible Controls**: Enable/disable controls via comment/uncomment
- **Comprehensive Coverage**: Identity, networking, logging, data protection

### Reporting & Compliance
- **Multiple Formats**: JSON, Markdown, CSV reports
- **Compliance Evidence**: Framework mapping matrices
- **CI/CD Integration**: GitHub Actions, GitLab CI, Jenkins support
- **Audit Trails**: Complete history of policy evaluations

## 🔧 Configuration

### Environment Configuration

The system supports multiple environments with different configurations:

- **Local**: Development-friendly settings with verbose output
- **Dev**: Relaxed validation for development environments
- **Test**: Comprehensive testing with all controls enabled
- **Prod**: Strict validation with full compliance requirements

Configuration files are located in `config/environments/`:

```yaml
# config/environments/prod.yaml
scan:
  output_format: "json"
  severity_filter: "all"
  continue_on_error: false

security:
  credentials:
    sources:
      - "iam_roles"
      - "managed_identities"
```

### Control Management

Controls can be enabled or disabled by commenting/uncommenting policy blocks:

```rego
# CONTROL: NET-001
# TITLE: No public SSH access from 0.0.0.0/0
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.1

package terraform.security.aws.networking

deny contains msg if {
    # Policy logic here
}
```

## 📊 Available Commands

### Make Targets

```bash
make help           # Show all available commands
make install        # Install required dependencies
make setup          # Set up development environment
make validate       # Validate policy syntax
make scan           # Run security policy scan
make test           # Run all tests
make test-examples  # Test good and bad examples
make lint           # Lint code and policies
make clean          # Clean up generated files
```

### Environment-Specific Scans

```bash
make scan-dev       # Scan with development settings
make scan-test      # Scan with test settings
make scan-prod      # Scan with production settings
```

### Output Format Options

```bash
make scan-json      # Generate JSON report only
make scan-markdown  # Generate Markdown report only
make scan-both      # Generate both formats
```

### Severity Filtering

```bash
make scan-critical  # Show only critical violations
make scan-high      # Show high and critical violations
make scan-medium    # Show medium, high, and critical violations
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
make test

# Test example configurations
make test-examples

# Validate policy syntax
make validate

# Run linting
make lint
```

### Test Structure

- **Unit Tests**: Test individual policies and modules
- **Integration Tests**: Test end-to-end workflows
- **Example Tests**: Validate good and bad example configurations
- **Property-Based Tests**: Comprehensive validation across inputs

### Property-Based Testing

The system includes comprehensive property-based tests that validate universal properties across randomized inputs:

```bash
# Run all property-based tests
./scripts/run-pbt.sh

# Run specific property-based test
./scripts/run-pbt.sh --test policy-consistency

# Run with custom iterations
./scripts/run-pbt.sh --iterations 200 --parallel

# Quick development check
PBT_ITERATIONS=10 ./tests/test-policy-consistency.sh
```

Property-based tests validate:
- Policy evaluation consistency across environments
- Control toggle behavior (comment/uncomment)
- Violation report completeness and format
- Syntax error reporting quality
- Credential independence for offline operation

See [Property-Based Testing Guide](docs/property-based-testing.md) for detailed information.

## 📚 Documentation

- [Architecture Overview](docs/architecture.md) - System design and components
- [Property-Based Testing Guide](docs/property-based-testing.md) - Comprehensive PBT documentation
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions
- [FAQ](docs/faq.md) - Frequently asked questions
- [Credential Management](docs/credential-management.md) - Secure credential handling
- [Policy Development Guide](docs/policy-development.md) - Creating and managing policies
- [Landing Zone Guide](docs/landing-zones.md) - Using Terraform modules
- [CI/CD Integration](docs/ci-cd.md) - Pipeline integration examples

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines.

## 🔒 Security

This project implements security best practices:

- No hardcoded credentials or secrets
- Secure credential handling via standard providers
- Audit logging for security events
- Secret scanning and detection
- Least-privilege access patterns

Report security vulnerabilities to [SECURITY.md](SECURITY.md).

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support & Troubleshooting

### Common Issues

#### 1. "Command not found" errors

**Problem**: `terraform`, `conftest`, or `opa` command not found
**Solution**:
```bash
# Check if tools are installed
which terraform conftest opa

# If missing, install using package manager or manual installation
make install

# Verify PATH includes installation directory
echo $PATH
```

#### 2. Permission denied errors

**Problem**: Scripts fail with permission errors
**Solution**:
```bash
# Make scripts executable
chmod +x scripts/*.sh

# Or run with explicit bash
bash scripts/scan.sh
```

#### 3. Terraform plan generation fails

**Problem**: `terraform plan` command fails during scan
**Solution**:
```bash
# Ensure Terraform is initialized
terraform init

# Check for syntax errors
terraform validate

# Verify provider credentials are configured
terraform plan
```

#### 4. Policy evaluation errors

**Problem**: Conftest fails to evaluate policies
**Solution**:
```bash
# Validate policy syntax
make validate

# Check specific policy file
conftest verify --policy policies/aws/identity/ examples/good/aws-basic/plan.json

# Enable verbose output for debugging
./scripts/scan.sh --verbose
```

#### 5. No violations detected when expected

**Problem**: Scan shows 0 violations but infrastructure has issues
**Solution**:
```bash
# Check if controls are enabled
./scripts/list-controls.sh

# Verify policy files are not commented out
grep -r "^#.*deny\|^#.*violation" policies/

# Test with known bad example
./scripts/scan.sh -d examples/bad/aws-violations
```

#### 6. Reports not generated

**Problem**: Scan completes but no reports found
**Solution**:
```bash
# Check output directory permissions
ls -la reports/

# Verify output format setting
./scripts/scan.sh -o both

# Check for disk space
df -h
```

### Getting Help

- **Documentation**: Check the [docs/](docs/) directory for detailed guides
- **Issues**: Open an issue on GitHub with:
  - Operating system and version
  - Tool versions (`terraform version`, `conftest --version`, `opa version`)
  - Complete error message
  - Steps to reproduce
- **Discussions**: Use GitHub Discussions for questions and community support
- **Security**: Follow responsible disclosure in [SECURITY.md](SECURITY.md)

### Debug Mode

Enable debug mode for detailed troubleshooting:

```bash
# Enable verbose logging
export DEBUG=1
./scripts/scan.sh --verbose

# Enable trace mode for scripts
bash -x scripts/scan.sh

# Check individual components
./scripts/validate-policies.sh
./scripts/generate-plan.sh -d examples/good/aws-basic
./scripts/run-conftest.sh examples/good/aws-basic/plan.json
```

### Performance Troubleshooting

#### Large Terraform Plans

For large infrastructure with many resources:

```bash
# Increase timeout values
export TERRAFORM_TIMEOUT=300
export CONFTEST_TIMEOUT=120

# Use streaming mode for large plans
./scripts/scan.sh --stream-mode

# Filter to specific resource types
./scripts/scan.sh --resource-types "aws_s3_bucket,aws_security_group"
```

#### Memory Issues

If running out of memory during scans:

```bash
# Monitor memory usage
./scripts/scan.sh --memory-profile

# Use incremental scanning
./scripts/scan.sh --incremental

# Reduce parallel processing
export MAX_PARALLEL_POLICIES=2
```

## 🗺️ Roadmap

- [ ] Additional cloud provider support (GCP)
- [ ] Enhanced framework mappings (SOC 2, FedRAMP)
- [ ] Policy marketplace and sharing
- [ ] Advanced reporting and dashboards
- [ ] Integration with security tools (SIEM, SOAR)

---

**Built with ❤️ for secure infrastructure automation**