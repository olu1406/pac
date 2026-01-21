# Contributing to Multi-Cloud Security Policy System

Thank you for your interest in contributing to the Multi-Cloud Security Policy System! This document provides guidelines and information for contributors.

## 🤝 Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please read and follow our community guidelines to ensure a welcoming environment for everyone.

## 🚀 Getting Started

### Prerequisites

Before contributing, ensure you have:

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Conftest](https://www.conftest.dev/install/) >= 0.30
- [Open Policy Agent (OPA)](https://www.openpolicyagent.org/docs/latest/#running-opa) >= 0.40
- [Git](https://git-scm.com/) for version control
- A GitHub account

### Development Setup

1. **Fork and clone the repository:**
   ```bash
   git clone https://github.com/your-username/multi-cloud-security-policy.git
   cd multi-cloud-security-policy
   ```

2. **Set up the development environment:**
   ```bash
   make setup
   ```

3. **Verify the setup:**
   ```bash
   make validate
   make test
   ```

## 📝 How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue templates** when available
3. **Provide detailed information** including:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Terraform version, etc.)
   - Relevant logs or error messages

### Suggesting Features

For feature requests:

1. **Check the roadmap** to see if it's already planned
2. **Open a discussion** before implementing large features
3. **Describe the use case** and expected benefits
4. **Consider backward compatibility** implications

### Contributing Code

#### Types of Contributions

- **Bug fixes**: Fix existing functionality
- **New policies**: Add security controls for AWS/Azure
- **New modules**: Add Terraform landing zone modules
- **Documentation**: Improve or add documentation
- **Tests**: Add or improve test coverage
- **Tools**: Enhance scripts and automation

#### Development Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes:**
   - Follow the coding standards (see below)
   - Add tests for new functionality
   - Update documentation as needed

3. **Test your changes:**
   ```bash
   make validate
   make test
   make lint
   ```

4. **Commit your changes:**
   ```bash
   git add .
   git commit -m "feat: add new AWS S3 encryption policy"
   ```

5. **Push and create a pull request:**
   ```bash
   git push origin feature/your-feature-name
   ```

## 📋 Coding Standards

### General Guidelines

- **Follow existing patterns** in the codebase
- **Write clear, self-documenting code**
- **Add comments for complex logic**
- **Keep functions small and focused**
- **Use meaningful variable and function names**

### Rego Policies

```rego
# CONTROL: S3-001
# TITLE: S3 buckets must have encryption enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-13, CIS-AWS:2.1.1
# DESCRIPTION: Ensures all S3 buckets have server-side encryption configured

package terraform.security.aws.s3

import rego.v1

# Deny S3 buckets without encryption
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    
    msg := {
        "control_id": "S3-001",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "S3 bucket must have server-side encryption enabled",
        "remediation": "Add server_side_encryption_configuration block"
    }
}

# Helper function to check encryption
has_encryption(resource) if {
    resource.values.server_side_encryption_configuration
}
```

### Terraform Modules

```hcl
# Use consistent variable naming
variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod."
  }
}

# Include comprehensive outputs
output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

# Use consistent tagging
locals {
  common_tags = {
    Environment = var.environment
    Project     = "multi-cloud-security-policy"
    ManagedBy   = "terraform"
  }
}
```

### Shell Scripts

```bash
#!/bin/bash

# Use strict error handling
set -euo pipefail

# Include script metadata
# Script: example-script.sh
# Purpose: Example shell script following project standards
# Author: Contributor Name

# Use consistent function naming
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

# Include usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Description of what this script does.

OPTIONS:
    -h, --help    Show this help message
EOF
}
```

### Documentation

- **Use clear, concise language**
- **Include code examples**
- **Keep documentation up-to-date**
- **Follow Markdown best practices**
- **Use consistent formatting**

## 🧪 Testing Guidelines

### Test Requirements

All contributions must include appropriate tests:

- **Unit tests** for individual functions/policies
- **Integration tests** for end-to-end workflows
- **Example tests** for Terraform modules
- **Documentation tests** for code examples

### Writing Tests

```bash
#!/bin/bash
# Test script example

test_policy_validation() {
    local test_name="S3 encryption policy validation"
    local policy_file="policies/aws/s3/encryption.rego"
    local test_input="tests/fixtures/s3-no-encryption.json"
    
    echo "Testing: $test_name"
    
    if conftest verify --policy "$policy_file" "$test_input"; then
        echo "❌ Test failed: Policy should have detected violation"
        return 1
    else
        echo "✅ Test passed: Policy correctly detected violation"
        return 0
    fi
}
```

### Running Tests

```bash
# Run all tests
make test

# Run specific test categories
make test-policies
make test-modules
make test-examples

# Run tests with coverage
make test-coverage
```

## 📚 Documentation Guidelines

### Types of Documentation

- **README**: Project overview and quick start
- **API Documentation**: Function and module interfaces
- **User Guides**: Step-by-step instructions
- **Developer Guides**: Technical implementation details
- **Examples**: Working code samples

### Documentation Standards

- **Keep it current**: Update docs with code changes
- **Be comprehensive**: Cover all features and options
- **Use examples**: Show real-world usage
- **Be accessible**: Write for different skill levels
- **Test examples**: Ensure code samples work

## 🔍 Review Process

### Pull Request Guidelines

- **Use descriptive titles** that explain the change
- **Fill out the PR template** completely
- **Link related issues** using keywords (fixes #123)
- **Keep PRs focused** on a single feature or fix
- **Include tests** for new functionality
- **Update documentation** as needed

### Review Criteria

Reviewers will check for:

- **Functionality**: Does the code work as intended?
- **Tests**: Are there adequate tests with good coverage?
- **Documentation**: Is documentation updated and clear?
- **Standards**: Does the code follow project conventions?
- **Security**: Are there any security implications?
- **Performance**: Are there any performance concerns?

### Addressing Feedback

- **Respond promptly** to review comments
- **Ask questions** if feedback is unclear
- **Make requested changes** or explain why not
- **Test changes** after addressing feedback
- **Request re-review** when ready

## 🏷️ Commit Message Guidelines

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(aws): add S3 bucket encryption policy

Add new Rego policy to enforce S3 bucket encryption.
Includes tests and documentation updates.

Closes #123
```

```
fix(scan): handle missing terraform binary gracefully

Improve error handling when terraform is not installed.
Provide clear error message with installation instructions.
```

## 🎯 Areas for Contribution

### High Priority

- **New security policies** for AWS and Azure
- **Additional framework mappings** (SOC 2, FedRAMP)
- **Improved error handling** and user experience
- **Performance optimizations** for large Terraform plans

### Medium Priority

- **Additional cloud providers** (GCP, Oracle Cloud)
- **Enhanced reporting** features and formats
- **CI/CD integrations** for more platforms
- **Policy testing** frameworks and tools

### Low Priority

- **UI/Dashboard** for policy management
- **Policy marketplace** and sharing features
- **Advanced analytics** and metrics
- **Integration** with external security tools

## 🆘 Getting Help

If you need help:

1. **Check the documentation** in the `docs/` directory
2. **Search existing issues** and discussions
3. **Ask in GitHub Discussions** for general questions
4. **Open an issue** for bugs or specific problems
5. **Join our community** channels (if available)

## 📄 License

By contributing to this project, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

Thank you for contributing to making infrastructure more secure! 🛡️