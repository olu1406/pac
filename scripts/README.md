# Scripts Directory

This directory contains automation scripts for the Multi-Cloud Security Policy System.

## Scripts

### Core Scripts

- **`scan.sh`**: Main orchestration script for policy validation
- **`generate-plan.sh`**: Terraform plan generation (to be implemented)
- **`run-conftest.sh`**: Conftest integration script (to be implemented)
- **`validate-policies.sh`**: Policy syntax validation (to be implemented)

### Utility Scripts

- **`setup-credentials.sh`**: Multi-cloud credential management and validation
- **`scan-secrets.sh`**: Secret detection and security scanning with audit logging
- **`generate-report.sh`**: Report generation (to be implemented)
- **`toggle-control.sh`**: Control management (to be implemented)

### Development Scripts

- **`dev-setup.sh`**: Development environment setup (to be implemented)
- **`generate-docs.sh`**: Documentation generation (to be implemented)
- **`new-control.sh`**: Control scaffolding (to be implemented)

## Usage

All scripts are designed to be:
- **POSIX compliant**: Work across different Unix-like systems
- **Self-documenting**: Include help text and usage information
- **Error handling**: Proper exit codes and error messages
- **Configurable**: Support environment variables and command-line options

### Secret Scanning

The `scan-secrets.sh` script detects hardcoded secrets and credentials in the repository:

```bash
# Scan current directory
./scripts/scan-secrets.sh

# Scan specific directory with verbose output
./scripts/scan-secrets.sh -d ./modules -v

# Generate both JSON and markdown reports
./scripts/scan-secrets.sh -o both

# Exclude specific directories and files
./scripts/scan-secrets.sh -e ".git,node_modules" -f "*.log,*.tmp"
```

**Features:**
- Detects AWS access keys, API tokens, passwords, and private keys
- Filters out known example/dummy credentials
- Generates structured JSON and human-readable markdown reports
- Secure audit logging without exposing sensitive data
- Configurable exclusions for directories and file patterns

## Script Standards

### Error Handling
```bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
```

### Logging
```bash
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
```

### Usage Information
```bash
usage() {
    cat << EOF
Usage: $0 [OPTIONS]
Description of what this script does.
EOF
}
```

### Configuration
```bash
# Support environment variables with defaults
VARIABLE="${VARIABLE:-default_value}"
```