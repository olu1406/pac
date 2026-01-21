# Example Configurations

This directory contains example Terraform configurations for testing and demonstration purposes.

## Structure

```
examples/
├── good/          # Compliant configurations (should pass all policies)
│   ├── aws-basic/       # Basic AWS setup that passes all controls
│   ├── azure-basic/     # Basic Azure setup that passes all controls
│   └── multi-cloud/     # Multi-cloud setup example
└── bad/           # Non-compliant configurations (should trigger violations)
    ├── aws-violations/  # AWS configs with intentional violations
    ├── azure-violations/ # Azure configs with intentional violations
    └── common-issues/   # Common security misconfigurations
```

## Purpose

### Good Examples
- Demonstrate secure configuration patterns
- Serve as templates for new projects
- Validate that policies don't have false positives
- Provide learning resources for best practices

### Bad Examples
- Test policy effectiveness
- Demonstrate common security mistakes
- Validate that policies catch real issues
- Provide training materials for security awareness

## Usage

### Testing Good Examples
```bash
# Test that good examples pass all policies
make test-examples

# Test specific good example
TERRAFORM_DIR=examples/good/aws-basic make scan
```

### Testing Bad Examples
```bash
# Test that bad examples trigger expected violations
for example in examples/bad/*/; do
    TERRAFORM_DIR="$example" make scan
done
```

## Contributing Examples

When adding new examples:

1. **Good Examples**: Should pass all enabled policies
2. **Bad Examples**: Should trigger specific, documented violations
3. **Documentation**: Include README explaining the security implications
4. **Testing**: Add to automated test suite

### Example Structure

Each example should include:
- `main.tf`: Primary Terraform configuration
- `variables.tf`: Variable definitions
- `outputs.tf`: Output definitions
- `README.md`: Explanation and security notes
- `terraform.tfvars.example`: Example variable values