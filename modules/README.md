# Terraform Landing Zone Modules

This directory contains secure-by-default Terraform modules for AWS and Azure landing zones.

## Structure

```
modules/
├── aws/           # AWS landing zone modules
│   ├── organization/    # AWS Organizations setup
│   ├── networking/      # VPC and networking baseline
│   ├── identity/        # IAM baseline configuration
│   ├── logging/         # CloudTrail, Config, GuardDuty
│   └── security/        # Security Hub, Inspector
└── azure/         # Azure landing zone modules
    ├── management-groups/  # Management group hierarchy
    ├── networking/         # VNet and networking baseline
    ├── identity/           # RBAC and identity baseline
    ├── logging/            # Activity logs, diagnostics
    └── security/           # Defender for Cloud, Policy
```

## Usage

Each module is designed to be:
- **Secure by default**: Implements security best practices
- **Environment agnostic**: Works across dev/test/prod
- **Composable**: Can be used independently or together
- **Well documented**: Includes examples and variable descriptions

## Getting Started

See the individual module directories for specific usage instructions and examples.