# Credential Management

The Multi-Cloud Security Policy System includes comprehensive credential management capabilities through the `scripts/setup-credentials.sh` script.

## Overview

The credential management script supports multiple authentication methods for both AWS and Azure:

- **Environment Variables**: Standard cloud provider environment variables
- **IAM Roles**: AWS IAM roles and Azure managed identities  
- **Credential Files**: Standard credential file formats (local development only)
- **Interactive Setup**: Guided credential configuration

## Usage

### Basic Usage

```bash
# Auto-detect and validate credentials for both clouds
./scripts/setup-credentials.sh

# Validate existing credentials only
./scripts/setup-credentials.sh --validate-only

# Setup AWS credentials only
./scripts/setup-credentials.sh --provider aws

# Interactive credential setup
./scripts/setup-credentials.sh --method interactive
```

### Command Line Options

- `-p, --provider PROVIDER`: Cloud provider (aws, azure, both)
- `-m, --method METHOD`: Credential method (env, role, file, interactive, auto)
- `-v, --validate-only`: Only validate existing credentials
- `-d, --dry-run`: Show what would be done without making changes
- `--verbose`: Enable verbose output
- `-h, --help`: Show help message

## Supported Credential Methods

### Environment Variables

**AWS:**
```bash
export AWS_ACCESS_KEY_ID=your-access-key-id
export AWS_SECRET_ACCESS_KEY=your-secret-access-key
export AWS_REGION=us-east-1
```

**Azure:**
```bash
export AZURE_CLIENT_ID=your-client-id
export AZURE_CLIENT_SECRET=your-client-secret
export AZURE_TENANT_ID=your-tenant-id
export AZURE_SUBSCRIPTION_ID=your-subscription-id
```

### IAM Roles and Managed Identities

**AWS IAM Roles:**
```bash
export AWS_ROLE_ARN=arn:aws:iam::123456789012:role/SecurityScannerRole
```

**Azure Managed Identity:**
- Automatically detected when running on Azure VMs
- No additional configuration required

### Credential Files

**AWS:**
- `~/.aws/credentials`
- `~/.aws/config`

**Azure:**
- `~/.azure/credentials`
- Azure CLI login: `az login`

## Security Features

### Credential Validation

The script validates credentials by:
- Testing AWS credentials with `aws sts get-caller-identity`
- Testing Azure credentials with `az account show`
- Checking for instance profiles and managed identities

### Security Checks

- Detects hardcoded credentials in environment
- Warns about local development environment usage
- Provides secure credential handling guidance
- Never logs sensitive credential information

### Best Practices

1. **Use least-privilege credentials**
2. **Rotate credentials regularly**
3. **Use temporary credentials when possible**
4. **Never commit credentials to version control**
5. **Use managed identities in cloud environments**

## Integration

### CI/CD Pipelines

```yaml
# GitHub Actions example
- name: Setup Credentials
  run: ./scripts/setup-credentials.sh --validate-only
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

### Local Development

```bash
# Setup development environment
export AWS_PROFILE=dev-scanner
export AZURE_CLIENT_ID=dev-client-id
./scripts/setup-credentials.sh --validate-only
```

## Troubleshooting

### Common Issues

**No credentials found:**
```bash
# Check environment variables
env | grep -E "(AWS_|AZURE_|ARM_)"

# Validate specific provider
./scripts/setup-credentials.sh --provider aws --validate-only
```

**Invalid credentials:**
```bash
# Test AWS credentials manually
aws sts get-caller-identity

# Test Azure credentials manually
az account show
```

**Permission errors:**
- Ensure credentials have required permissions
- Check IAM policies and Azure RBAC assignments
- Verify subscription and tenant access

### Debug Mode

```bash
# Enable verbose output for debugging
./scripts/setup-credentials.sh --verbose --validate-only
```

## Requirements Compliance

This implementation satisfies the following requirements:

- **11.4**: Support for standard credential providers (environment variables, IAM roles, managed identities)
- **11.1**: No hardcoded secrets or credentials in code
- **11.3**: Works without cloud credentials for basic policy validation
- **11.5**: Secure logging without exposing sensitive information

## Testing

The credential management script includes comprehensive tests:

```bash
# Run credential setup tests
./tests/test-credential-setup.sh
```

Tests cover:
- Script existence and permissions
- Argument validation
- Credential method selection
- Security checks
- Error handling