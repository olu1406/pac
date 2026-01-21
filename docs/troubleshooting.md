# Troubleshooting Guide

This guide provides detailed troubleshooting information for common issues encountered when using the Multi-Cloud Security Policy System.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Problems](#configuration-problems)
- [Scanning Issues](#scanning-issues)
- [Policy Development](#policy-development)
- [Performance Issues](#performance-issues)
- [CI/CD Integration](#cicd-integration)
- [Cloud Provider Issues](#cloud-provider-issues)
- [Debugging Tools](#debugging-tools)

## Installation Issues

### Tool Installation Problems

#### Terraform Installation

**Issue**: Terraform not found or wrong version
```bash
terraform: command not found
# or
Terraform v0.14.0 (required >= 1.0)
```

**Solutions**:
```bash
# macOS with Homebrew
brew install terraform

# Linux manual installation
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installation
terraform version
```

#### Conftest Installation

**Issue**: Conftest not available or incompatible version
```bash
conftest: command not found
# or
conftest version 0.25.0 (required >= 0.30)
```

**Solutions**:
```bash
# macOS with Homebrew
brew install conftest

# Linux manual installation
wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# Verify installation
conftest --version
```

#### OPA Installation

**Issue**: OPA not found or version mismatch
```bash
opa: command not found
# or
Open Policy Agent 0.35.0 (required >= 0.40)
```

**Solutions**:
```bash
# macOS with Homebrew
brew install opa

# Linux manual installation
curl -L -o opa https://openpolicyagent.org/downloads/v0.57.0/opa_linux_amd64_static
chmod 755 ./opa
sudo mv opa /usr/local/bin/

# Verify installation
opa version
```

### Permission Issues

#### Script Execution Permissions

**Issue**: Permission denied when running scripts
```bash
./scripts/scan.sh: Permission denied
```

**Solutions**:
```bash
# Make all scripts executable
chmod +x scripts/*.sh

# Or run with explicit bash
bash scripts/scan.sh

# Check current permissions
ls -la scripts/
```

#### Directory Access Issues

**Issue**: Cannot write to reports directory
```bash
mkdir: cannot create directory 'reports': Permission denied
```

**Solutions**:
```bash
# Create reports directory with proper permissions
mkdir -p reports
chmod 755 reports

# Check current directory permissions
ls -la

# Run with sudo if necessary (not recommended for production)
sudo ./scripts/scan.sh
```

## Configuration Problems

### Environment Configuration

#### Invalid Configuration File

**Issue**: Configuration file syntax errors
```bash
Error: Invalid YAML syntax in config/environments/prod.yaml
```

**Solutions**:
```bash
# Validate YAML syntax
python -c "import yaml; yaml.safe_load(open('config/environments/prod.yaml'))"

# Or use online YAML validator
# Check for common issues:
# - Incorrect indentation
# - Missing quotes around special characters
# - Invalid boolean values

# Example valid configuration:
cat > config/environments/prod.yaml << EOF
scan:
  output_format: "json"
  severity_filter: "all"
  continue_on_error: false
security:
  credentials:
    sources:
      - "iam_roles"
      - "managed_identities"
EOF
```

#### Missing Environment Configuration

**Issue**: Environment configuration not found
```bash
Error: Configuration file not found: config/environments/custom.yaml
```

**Solutions**:
```bash
# List available environments
ls config/environments/

# Copy from existing environment
cp config/environments/prod.yaml config/environments/custom.yaml

# Or use default configuration
./scripts/scan.sh -e default
```

### Credential Configuration

#### AWS Credentials

**Issue**: AWS credentials not configured
```bash
Error: No credentials found for AWS provider
```

**Solutions**:
```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Or use AWS CLI configuration
aws configure

# Or use IAM roles (recommended for CI/CD)
# Ensure EC2 instance or container has appropriate IAM role

# Verify credentials
aws sts get-caller-identity
```

#### Azure Credentials

**Issue**: Azure credentials not configured
```bash
Error: No credentials found for Azure provider
```

**Solutions**:
```bash
# Use Azure CLI
az login

# Or set environment variables
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"

# Or use managed identity (recommended for CI/CD)
# Ensure VM or container has appropriate managed identity

# Verify credentials
az account show
```

## Scanning Issues

### Terraform Plan Generation

#### Plan Generation Failures

**Issue**: Terraform plan command fails
```bash
Error: terraform plan failed with exit code 1
```

**Solutions**:
```bash
# Initialize Terraform first
terraform init

# Check for syntax errors
terraform validate

# Run plan manually to see detailed error
terraform plan

# Common fixes:
# - Update provider versions
# - Fix variable references
# - Resolve resource dependencies
# - Check provider authentication
```

#### Large Plan Files

**Issue**: Terraform plan JSON is too large
```bash
Error: Plan file exceeds maximum size limit
```

**Solutions**:
```bash
# Use targeted planning
terraform plan -target=module.specific_module

# Enable streaming mode
export ENABLE_STREAMING=true
./scripts/scan.sh

# Increase memory limits
export MAX_PLAN_SIZE=100MB
./scripts/scan.sh

# Split large configurations into smaller modules
```

### Policy Evaluation

#### Policy Syntax Errors

**Issue**: Rego policy syntax errors
```bash
Error: policy compilation failed
1 error occurred: policy.rego:15: rego_parse_error: unexpected token
```

**Solutions**:
```bash
# Validate specific policy file
opa fmt policies/aws/identity/iam_policies.rego

# Check syntax with conftest
conftest verify --policy policies/aws/identity/ --data examples/good/aws-basic/plan.json

# Common syntax issues:
# - Missing semicolons
# - Incorrect indentation
# - Invalid variable names
# - Malformed rules

# Use OPA playground for testing: https://play.openpolicyagent.org/
```

#### Policy Loading Issues

**Issue**: Policies not found or loaded
```bash
Error: No policies found in directory: policies/
```

**Solutions**:
```bash
# Check policy directory structure
find policies/ -name "*.rego" -type f

# Verify policy file permissions
ls -la policies/aws/identity/

# Check for hidden files or incorrect extensions
ls -la policies/aws/identity/*.rego

# Ensure policies are not commented out entirely
grep -r "package\|deny\|violation" policies/
```

### Report Generation

#### Report Output Issues

**Issue**: Reports not generated or empty
```bash
Warning: No violations found, but reports not generated
```

**Solutions**:
```bash
# Check output directory permissions
ls -la reports/

# Verify output format configuration
./scripts/scan.sh -o both --verbose

# Check for disk space
df -h

# Test report generation manually
echo '{"violations": []}' | ./scripts/generate-report.sh
```

#### Report Format Issues

**Issue**: Invalid JSON or malformed Markdown
```bash
Error: Invalid JSON in report file
```

**Solutions**:
```bash
# Validate JSON report
jq '.' reports/scan-report.json

# Check for special characters in violation messages
grep -r "[^[:print:]]" reports/

# Regenerate reports with clean data
rm reports/*
./scripts/scan.sh -o both
```

## Policy Development

### Writing New Policies

#### Rule Logic Errors

**Issue**: Policy rules not triggering as expected
```bash
Expected violation not detected for test case
```

**Solutions**:
```bash
# Test policy with minimal input
echo '{"planned_values": {"root_module": {"resources": []}}}' | \
  conftest verify --policy policies/aws/identity/ -

# Add debug output to policy
deny[msg] {
    # Add trace for debugging
    trace(sprintf("Checking resource: %v", [input.planned_values.root_module.resources[_]]))
    
    # Your policy logic here
    condition
    
    msg := "Violation message"
}

# Use OPA eval for testing
opa eval -d policies/aws/identity/ -i plan.json "data.terraform.security.aws.identity.deny"
```

#### Test Case Development

**Issue**: Test cases failing unexpectedly
```bash
Test case 'should_deny_public_s3' failed: expected violation not found
```

**Solutions**:
```bash
# Verify test input structure
jq '.' tests/fixtures/bad_s3_public.json

# Check policy package path
grep "package" policies/aws/data/s3_encryption.rego

# Ensure test data matches policy expectations
# Policy expects: input.planned_values.root_module.resources[_]
# Test should provide matching structure

# Run individual test
conftest verify --policy policies/aws/data/ tests/fixtures/bad_s3_public.json
```

### Control Management

#### Control Toggle Issues

**Issue**: Commenting/uncommenting controls doesn't work
```bash
Control still active after commenting out
```

**Solutions**:
```bash
# Check control block structure
grep -A 10 -B 5 "CONTROL: NET-001" policies/aws/networking/

# Ensure entire rule block is commented
# Incorrect:
# deny[msg] {
#     condition
# }

# Correct:
# deny[msg] {
#     condition
# }

# Verify with list-controls script
./scripts/list-controls.sh
```

## Performance Issues

### Slow Scanning

#### Large Infrastructure

**Issue**: Scans take too long for large Terraform configurations
```bash
Scan timeout after 300 seconds
```

**Solutions**:
```bash
# Increase timeout values
export TERRAFORM_TIMEOUT=600
export CONFTEST_TIMEOUT=300

# Enable parallel processing
export MAX_PARALLEL_POLICIES=4

# Use incremental scanning
./scripts/scan.sh --incremental

# Profile performance
time ./scripts/scan.sh --profile
```

#### Memory Usage

**Issue**: High memory consumption during scans
```bash
Error: Out of memory during policy evaluation
```

**Solutions**:
```bash
# Monitor memory usage
./scripts/scan.sh --memory-profile

# Reduce batch size
export POLICY_BATCH_SIZE=10

# Use streaming mode for large plans
export ENABLE_STREAMING=true

# Increase system memory or use smaller chunks
split -l 1000 plan.json plan_chunk_
```

### Network Issues

#### Slow Downloads

**Issue**: Slow provider or module downloads
```bash
Terraform initialization taking too long
```

**Solutions**:
```bash
# Use local mirror for providers
terraform providers mirror ./terraform-providers

# Configure provider cache
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
mkdir -p $TF_PLUGIN_CACHE_DIR

# Use faster mirror
export TF_CLI_CONFIG_FILE="$HOME/.terraformrc"
cat > $HOME/.terraformrc << EOF
provider_installation {
  network_mirror {
    url = "https://terraform-mirror.example.com/"
  }
}
EOF
```

## CI/CD Integration

### GitHub Actions Issues

#### Action Failures

**Issue**: GitHub Actions workflow fails
```bash
Error: Process completed with exit code 1
```

**Solutions**:
```bash
# Check workflow file syntax
yamllint .github/workflows/ci.yml

# Verify action versions
# Use specific versions instead of @main
- uses: actions/checkout@v3
- uses: hashicorp/setup-terraform@v2

# Add debug output
- name: Debug Environment
  run: |
    echo "Working directory: $(pwd)"
    echo "Files: $(ls -la)"
    echo "PATH: $PATH"
    which terraform conftest opa
```

#### Artifact Upload Issues

**Issue**: Reports not uploaded as artifacts
```bash
Warning: No files were found with the provided path: reports/
```

**Solutions**:
```bash
# Ensure reports directory exists
- name: Create Reports Directory
  run: mkdir -p reports

# Check if reports were generated
- name: List Reports
  run: ls -la reports/

# Use conditional upload
- name: Upload Reports
  uses: actions/upload-artifact@v3
  if: always()
  with:
    name: security-reports
    path: reports/
    if-no-files-found: warn
```

### GitLab CI Issues

#### Runner Configuration

**Issue**: GitLab runner lacks required tools
```bash
/bin/sh: terraform: not found
```

**Solutions**:
```yaml
# Use image with pre-installed tools
image: hashicorp/terraform:latest

# Or install in before_script
before_script:
  - apk add --no-cache curl wget unzip
  - wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
  - unzip terraform_1.6.0_linux_amd64.zip
  - mv terraform /usr/local/bin/
  - wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
  - tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
  - mv conftest /usr/local/bin/
```

## Cloud Provider Issues

### AWS-Specific Issues

#### IAM Permission Errors

**Issue**: Insufficient IAM permissions
```bash
Error: AccessDenied: User is not authorized to perform: sts:GetCallerIdentity
```

**Solutions**:
```bash
# Minimum required permissions for scanning:
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity",
        "iam:ListRoles",
        "iam:ListPolicies",
        "ec2:DescribeVpcs",
        "ec2:DescribeSecurityGroups",
        "s3:ListBucket",
        "s3:GetBucketEncryption"
      ],
      "Resource": "*"
    }
  ]
}

# For read-only scanning, use AWS managed policy:
# arn:aws:iam::aws:policy/ReadOnlyAccess
```

#### Region Issues

**Issue**: Resources not found in specified region
```bash
Error: No VPCs found in region us-west-2
```

**Solutions**:
```bash
# Set correct region
export AWS_DEFAULT_REGION="us-east-1"

# Or specify in Terraform configuration
provider "aws" {
  region = "us-east-1"
}

# List available regions
aws ec2 describe-regions --output table
```

### Azure-Specific Issues

#### Subscription Access

**Issue**: Cannot access Azure subscription
```bash
Error: Subscription not found or access denied
```

**Solutions**:
```bash
# List available subscriptions
az account list --output table

# Set correct subscription
az account set --subscription "your-subscription-id"

# Verify permissions
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Required roles for scanning:
# - Reader (minimum)
# - Security Reader (recommended)
```

#### Resource Provider Registration

**Issue**: Resource provider not registered
```bash
Error: The subscription is not registered to use namespace 'Microsoft.Security'
```

**Solutions**:
```bash
# Register required resource providers
az provider register --namespace Microsoft.Security
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Storage

# Check registration status
az provider list --query "[?namespace=='Microsoft.Security']" --output table
```

## Debugging Tools

### Enable Debug Mode

```bash
# Enable verbose logging for all scripts
export DEBUG=1
export VERBOSE=1

# Enable bash trace mode
bash -x scripts/scan.sh

# Enable Terraform debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform.log

# Enable OPA debug logging
export OPA_LOG_LEVEL=debug
```

### Component Testing

```bash
# Test individual components
./scripts/validate-policies.sh --verbose
./scripts/generate-plan.sh -d examples/good/aws-basic --debug
./scripts/run-conftest.sh examples/good/aws-basic/plan.json --trace

# Test policy evaluation manually
opa eval -d policies/aws/identity/ -i plan.json "data.terraform.security.aws.identity"

# Test report generation
echo '{"violations": [{"control_id": "TEST-001", "severity": "HIGH"}]}' | \
  ./scripts/generate-report.sh --format json
```

### Log Analysis

```bash
# Check system logs for errors
journalctl -u terraform --since "1 hour ago"

# Monitor resource usage during scans
top -p $(pgrep -f scan.sh)

# Check disk space and I/O
iostat -x 1 5
df -h

# Network connectivity testing
curl -I https://registry.terraform.io/
curl -I https://github.com/open-policy-agent/conftest/releases/
```

### Common Log Patterns

Look for these patterns in logs to identify issues:

```bash
# Permission errors
grep -i "permission denied\|access denied\|unauthorized" *.log

# Network errors
grep -i "connection refused\|timeout\|network unreachable" *.log

# Resource errors
grep -i "not found\|does not exist\|invalid" *.log

# Memory errors
grep -i "out of memory\|memory limit\|killed" *.log

# Syntax errors
grep -i "syntax error\|parse error\|invalid syntax" *.log
```

---

If you encounter an issue not covered in this guide, please:

1. Enable debug mode and collect logs
2. Check the [GitHub Issues](https://github.com/your-repo/issues) for similar problems
3. Create a new issue with:
   - Operating system and version
   - Tool versions
   - Complete error message
   - Steps to reproduce
   - Debug logs (sanitized of sensitive information)

For security-related issues, follow the responsible disclosure process outlined in [SECURITY.md](../SECURITY.md).

## Property-Based Testing Issues

### Test Execution Problems

#### Property-Based Tests Failing

**Issue**: Property-based tests report failures or inconsistent results
```bash
[ERROR] ❌ 5 out of 100 property-based test iterations failed
[WARN] Failing examples saved for debugging
```

**Diagnosis Steps**:
1. Check the failing examples in the `reports/` directory
2. Examine the specific property that failed
3. Verify tool versions and environment consistency

**Solutions**:
```bash
# Run with fewer iterations to isolate the issue
PBT_ITERATIONS=10 ./tests/test-policy-consistency.sh

# Run specific test with verbose output
VERBOSE=true ./tests/test-control-toggle.sh

# Check for environment differences
env | grep -E "(AWS|AZURE|TERRAFORM|CI)"

# Verify tool versions
opa version
conftest --version
terraform version
```

#### Slow Property-Based Test Performance

**Issue**: Property-based tests take too long to complete
```bash
# Tests running for more than 10 minutes
```

**Solutions**:
```bash
# Reduce iteration count for development
./scripts/run-pbt.sh --iterations 25

# Run tests in parallel
./scripts/run-pbt.sh --parallel --iterations 50

# Run specific test only
./scripts/run-pbt.sh --test policy-consistency --iterations 10

# Check system resources
top
df -h /tmp
```

#### Missing Dependencies for Property-Based Tests

**Issue**: Property-based tests fail due to missing tools
```bash
[ERROR] Missing dependencies: jq bc
```

**Solutions**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install jq bc

# macOS
brew install jq

# Verify installation
jq --version
bc --version
```

### Property-Based Test Interpretation

#### Understanding Test Results

**Issue**: Unclear what property-based test results mean

**Test Result Structure**:
```json
{
  "test_name": "policy_evaluation_consistency",
  "summary": {
    "total": 100,
    "passed": 95,
    "failed": 5,
    "success_rate": 95.0
  }
}
```

**Interpretation Guidelines**:
- **Success Rate > 95%**: Generally acceptable, may indicate rare edge cases
- **Success Rate 90-95%**: Investigate failing examples, may indicate systemic issues
- **Success Rate < 90%**: Likely indicates bugs or incorrect assumptions

#### Analyzing Failing Examples

**Issue**: Property-based test failures need investigation

**Debug Process**:
```bash
# 1. Examine failing examples
ls -la reports/failing_*

# 2. Look at the specific failing input
jq . reports/failing_plan_42.json

# 3. Compare different results (for consistency tests)
diff reports/failing_result_local_42.json reports/failing_result_ci_42.json

# 4. Reproduce manually
cp reports/failing_plan_42.json /tmp/test.json
conftest test --policy policies/ /tmp/test.json

# 5. Check for environment-specific issues
CI=true conftest test --policy policies/ /tmp/test.json
```

### Common Property-Based Test Issues

#### Policy Consistency Test Failures

**Issue**: Same policy evaluation produces different results in different environments

**Common Causes**:
- Different tool versions
- Environment variable differences
- File system case sensitivity
- Timezone differences in timestamps

**Solutions**:
```bash
# Standardize tool versions
docker run --rm -v $(pwd):/workspace openpolicyagent/conftest:latest test --policy /workspace/policies /workspace/plan.json

# Clear environment variables
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
unset AZURE_CLIENT_ID AZURE_CLIENT_SECRET

# Use consistent timestamps
export TZ=UTC
```

#### Control Toggle Test Failures

**Issue**: Controls not properly enabling/disabling

**Common Causes**:
- Incorrect comment syntax in policies
- Policy caching issues
- File permission problems

**Solutions**:
```bash
# Check policy syntax
opa fmt policies/

# Verify comment structure
grep -n "^#.*deny\|^deny" policies/aws/identity/iam_policies.rego

# Clear any caches
rm -rf .opa/
```

#### Report Format Test Failures

**Issue**: Generated reports missing required fields

**Common Causes**:
- Report generation script changes
- Policy output format changes
- JSON parsing issues

**Solutions**:
```bash
# Test report generation manually
./scripts/generate-report.sh --help

# Validate JSON structure
jq empty reports/violations.json

# Check required fields
jq '.violations[0] | keys' reports/violations.json
```

### Property-Based Test Development

#### Creating New Property-Based Tests

**Issue**: Need to add new property-based tests for additional system behaviors

**Template Structure**:
```bash
#!/bin/bash
# Property-Based Test: [Property Name]
# Feature: multi-cloud-security-policy, Property N: [Property Description]
# Validates: Requirements X.Y, Z.A

set -euo pipefail

# Test configuration
TEST_ITERATIONS=${PBT_ITERATIONS:-100}
TEMP_DIR=$(mktemp -d)

# Property test function
test_property() {
    local iteration="$1"
    # Generate test data
    # Run system operation
    # Validate property holds
    # Return PASS/FAIL
}

# Main test loop
for i in $(seq 1 $TEST_ITERATIONS); do
    result=$(test_property "$i")
    # Record results
done
```

#### Debugging Property-Based Test Logic

**Issue**: Property-based test logic needs debugging

**Debugging Techniques**:
```bash
# Add debug output
echo "DEBUG: Generated plan: $(cat $test_plan)" >&2

# Save intermediate results
cp "$intermediate_result" "/tmp/debug_$iteration.json"

# Use smaller iteration counts
PBT_ITERATIONS=5 ./tests/test-new-property.sh

# Enable verbose mode
VERBOSE=true ./tests/test-new-property.sh
```

### CI/CD Integration Issues

#### Property-Based Tests in CI

**Issue**: Property-based tests behave differently in CI environment

**Common Causes**:
- Resource constraints in CI
- Different tool versions
- Missing environment setup

**Solutions**:
```bash
# Reduce iterations for CI
env:
  PBT_ITERATIONS: 25

# Use consistent tool versions
- name: Setup OPA
  uses: open-policy-agent/setup-opa@v2
  with:
    version: 0.57.0

# Add resource monitoring
- name: Check resources
  run: |
    df -h
    free -m
    nproc
```

#### Property-Based Test Artifacts

**Issue**: Need to collect property-based test results in CI

**Solution**:
```yaml
- name: Upload property-based test results
  uses: actions/upload-artifact@v3
  if: always()
  with:
    name: pbt-results
    path: |
      reports/pbt_*.json
      reports/failing_*
```

For more detailed information about property-based testing, see the [Property-Based Testing Guide](property-based-testing.md).