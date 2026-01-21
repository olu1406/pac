#!/bin/bash

# Multi-Cloud Credential Management Script
# Handles AWS and Azure authentication with multiple credential methods

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default configuration
CLOUD_PROVIDER="${CLOUD_PROVIDER:-both}"
CREDENTIAL_METHOD="${CREDENTIAL_METHOD:-auto}"
VALIDATE_ONLY="${VALIDATE_ONLY:-false}"
VERBOSE="${VERBOSE:-false}"
DRY_RUN="${DRY_RUN:-false}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Multi-Cloud Credential Management Script

Supports AWS and Azure authentication with multiple credential methods:
- Environment variables
- IAM roles and managed identities
- Credential files (local development only)
- Interactive configuration

OPTIONS:
    -p, --provider PROVIDER     Cloud provider: aws, azure, both (default: both)
    -m, --method METHOD         Credential method: env, role, file, interactive, auto (default: auto)
    -v, --validate-only         Only validate existing credentials, don't configure
    -d, --dry-run              Show what would be done without making changes
    --verbose                   Enable verbose output
    -h, --help                 Show this help message

CREDENTIAL METHODS:
    env                        Use environment variables
    role                       Use IAM roles/managed identities
    file                       Use credential files (local development only)
    interactive                Interactive credential setup
    auto                       Auto-detect best available method

EXAMPLES:
    $0                         # Auto-detect and setup credentials for both clouds
    $0 -p aws -m env           # Setup AWS credentials using environment variables
    $0 -p azure -m role        # Setup Azure credentials using managed identity
    $0 --validate-only         # Only validate existing credentials
    $0 --dry-run               # Show what would be configured

ENVIRONMENT VARIABLES:
    # AWS Environment Variables
    AWS_ACCESS_KEY_ID          AWS access key ID
    AWS_SECRET_ACCESS_KEY      AWS secret access key
    AWS_SESSION_TOKEN          AWS session token (for temporary credentials)
    AWS_PROFILE                AWS profile name
    AWS_ROLE_ARN               AWS role ARN for assume role
    AWS_REGION                 AWS default region

    # Azure Environment Variables
    AZURE_CLIENT_ID            Azure client ID (service principal)
    AZURE_CLIENT_SECRET        Azure client secret
    AZURE_TENANT_ID            Azure tenant ID
    AZURE_SUBSCRIPTION_ID      Azure subscription ID
    ARM_CLIENT_ID              Alternative Azure client ID
    ARM_CLIENT_SECRET          Alternative Azure client secret
    ARM_TENANT_ID              Alternative Azure tenant ID
    ARM_SUBSCRIPTION_ID        Alternative Azure subscription ID

    # Script Configuration
    CLOUD_PROVIDER             Override default cloud provider
    CREDENTIAL_METHOD          Override default credential method
    VALIDATE_ONLY              Only validate credentials (true/false)
    VERBOSE                    Enable verbose output (true/false)
    DRY_RUN                    Show what would be done (true/false)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--provider)
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            -m|--method)
                CREDENTIAL_METHOD="$2"
                shift 2
                ;;
            -v|--validate-only)
                VALIDATE_ONLY="true"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate script arguments
validate_args() {
    case "$CLOUD_PROVIDER" in
        aws|azure|both) ;;
        *)
            log_error "Invalid cloud provider: $CLOUD_PROVIDER"
            log_info "Valid options: aws, azure, both"
            exit 1
            ;;
    esac
    
    case "$CREDENTIAL_METHOD" in
        env|role|file|interactive|auto) ;;
        *)
            log_error "Invalid credential method: $CREDENTIAL_METHOD"
            log_info "Valid options: env, role, file, interactive, auto"
            exit 1
            ;;
    esac
}

# Check if running in CI environment
is_ci_environment() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]] || [[ -n "${JENKINS_URL:-}" ]]
}

# Check if running in cloud environment
is_cloud_environment() {
    # Check for AWS EC2 instance metadata
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        return 0
    fi
    
    # Check for Azure instance metadata
    if curl -s --max-time 2 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# AWS credential validation functions
validate_aws_env_credentials() {
    log_debug "Validating AWS environment credentials"
    
    local required_vars=()
    
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
        required_vars+=("AWS_ACCESS_KEY_ID")
    fi
    
    if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        required_vars+=("AWS_SECRET_ACCESS_KEY")
    fi
    
    if [[ ${#required_vars[@]} -gt 0 ]]; then
        log_warn "Missing AWS environment variables: ${required_vars[*]}"
        return 1
    fi
    
    # Test credentials by calling STS GetCallerIdentity
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity &>/dev/null; then
            log_success "AWS environment credentials are valid"
            return 0
        else
            log_error "AWS environment credentials are invalid"
            return 1
        fi
    else
        log_warn "AWS CLI not available, cannot validate credentials"
        return 0
    fi
}

validate_aws_profile_credentials() {
    log_debug "Validating AWS profile credentials"
    
    if [[ -z "${AWS_PROFILE:-}" ]]; then
        log_warn "AWS_PROFILE not set"
        return 1
    fi
    
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity --profile "$AWS_PROFILE" &>/dev/null; then
            log_success "AWS profile credentials are valid: $AWS_PROFILE"
            return 0
        else
            log_error "AWS profile credentials are invalid: $AWS_PROFILE"
            return 1
        fi
    else
        log_warn "AWS CLI not available, cannot validate profile credentials"
        return 0
    fi
}

validate_aws_role_credentials() {
    log_debug "Validating AWS role credentials"
    
    if [[ -z "${AWS_ROLE_ARN:-}" ]]; then
        log_warn "AWS_ROLE_ARN not set"
        return 1
    fi
    
    if command -v aws &> /dev/null; then
        # Try to assume the role
        local session_name="credential-validation-$(date +%s)"
        if aws sts assume-role --role-arn "$AWS_ROLE_ARN" --role-session-name "$session_name" &>/dev/null; then
            log_success "AWS role credentials are valid: $AWS_ROLE_ARN"
            return 0
        else
            log_error "Cannot assume AWS role: $AWS_ROLE_ARN"
            return 1
        fi
    else
        log_warn "AWS CLI not available, cannot validate role credentials"
        return 0
    fi
}

validate_aws_instance_profile() {
    log_debug "Validating AWS instance profile"
    
    # Check if running on EC2 with instance profile
    if curl -s --max-time 2 http://169.254.169.254/latest/meta-data/iam/security-credentials/ &>/dev/null; then
        local role_name
        role_name=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/iam/security-credentials/)
        
        if [[ -n "$role_name" ]]; then
            log_success "AWS instance profile available: $role_name"
            return 0
        fi
    fi
    
    log_warn "No AWS instance profile available"
    return 1
}

# Azure credential validation functions
validate_azure_env_credentials() {
    log_debug "Validating Azure environment credentials"
    
    local required_vars=()
    local client_id="${AZURE_CLIENT_ID:-${ARM_CLIENT_ID:-}}"
    local client_secret="${AZURE_CLIENT_SECRET:-${ARM_CLIENT_SECRET:-}}"
    local tenant_id="${AZURE_TENANT_ID:-${ARM_TENANT_ID:-}}"
    
    if [[ -z "$client_id" ]]; then
        required_vars+=("AZURE_CLIENT_ID or ARM_CLIENT_ID")
    fi
    
    if [[ -z "$client_secret" ]]; then
        required_vars+=("AZURE_CLIENT_SECRET or ARM_CLIENT_SECRET")
    fi
    
    if [[ -z "$tenant_id" ]]; then
        required_vars+=("AZURE_TENANT_ID or ARM_TENANT_ID")
    fi
    
    if [[ ${#required_vars[@]} -gt 0 ]]; then
        log_warn "Missing Azure environment variables: ${required_vars[*]}"
        return 1
    fi
    
    # Test credentials by calling Azure Resource Manager
    if command -v az &> /dev/null; then
        # Set environment variables for az cli
        export AZURE_CLIENT_ID="$client_id"
        export AZURE_CLIENT_SECRET="$client_secret"
        export AZURE_TENANT_ID="$tenant_id"
        
        if az account show &>/dev/null; then
            log_success "Azure environment credentials are valid"
            return 0
        else
            # Try to login with service principal
            if az login --service-principal -u "$client_id" -p "$client_secret" --tenant "$tenant_id" &>/dev/null; then
                log_success "Azure service principal credentials are valid"
                return 0
            else
                log_error "Azure environment credentials are invalid"
                return 1
            fi
        fi
    else
        log_warn "Azure CLI not available, cannot validate credentials"
        return 0
    fi
}

validate_azure_cli_credentials() {
    log_debug "Validating Azure CLI credentials"
    
    if command -v az &> /dev/null; then
        if az account show &>/dev/null; then
            log_success "Azure CLI credentials are valid"
            return 0
        else
            log_warn "Azure CLI not logged in"
            return 1
        fi
    else
        log_warn "Azure CLI not available"
        return 1
    fi
}

validate_azure_managed_identity() {
    log_debug "Validating Azure managed identity"
    
    # Check if running on Azure VM with managed identity
    if curl -s --max-time 2 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" &>/dev/null; then
        # Try to get access token using managed identity
        if curl -s --max-time 2 -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" &>/dev/null; then
            log_success "Azure managed identity available"
            return 0
        fi
    fi
    
    log_warn "No Azure managed identity available"
    return 1
}

# Auto-detect best credential method
auto_detect_aws_credentials() {
    log_debug "Auto-detecting AWS credentials"
    
    # Priority order: instance profile, environment variables, profile, role
    if validate_aws_instance_profile; then
        echo "instance_profile"
    elif validate_aws_env_credentials; then
        echo "environment"
    elif validate_aws_profile_credentials; then
        echo "profile"
    elif validate_aws_role_credentials; then
        echo "role"
    else
        echo "none"
    fi
}

auto_detect_azure_credentials() {
    log_debug "Auto-detecting Azure credentials"
    
    # Priority order: managed identity, CLI, environment variables
    if validate_azure_managed_identity; then
        echo "managed_identity"
    elif validate_azure_cli_credentials; then
        echo "cli"
    elif validate_azure_env_credentials; then
        echo "environment"
    else
        echo "none"
    fi
}

# Setup credential methods
setup_aws_env_credentials() {
    log_info "Setting up AWS environment credentials"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would prompt for AWS access key ID and secret access key"
        return 0
    fi
    
    if [[ "$CREDENTIAL_METHOD" == "interactive" ]]; then
        read -rp "Enter AWS Access Key ID: " aws_access_key_id
        read -rsp "Enter AWS Secret Access Key: " aws_secret_access_key
        echo
        read -rp "Enter AWS Region (default: us-east-1): " aws_region
        aws_region="${aws_region:-us-east-1}"
        
        # Export variables for current session
        export AWS_ACCESS_KEY_ID="$aws_access_key_id"
        export AWS_SECRET_ACCESS_KEY="$aws_secret_access_key"
        export AWS_REGION="$aws_region"
        
        log_success "AWS environment credentials configured"
    else
        log_info "AWS environment credentials should be set via environment variables:"
        log_info "  export AWS_ACCESS_KEY_ID=your-access-key-id"
        log_info "  export AWS_SECRET_ACCESS_KEY=your-secret-access-key"
        log_info "  export AWS_REGION=your-preferred-region"
    fi
}

setup_azure_env_credentials() {
    log_info "Setting up Azure environment credentials"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would prompt for Azure service principal credentials"
        return 0
    fi
    
    if [[ "$CREDENTIAL_METHOD" == "interactive" ]]; then
        read -rp "Enter Azure Client ID: " azure_client_id
        read -rsp "Enter Azure Client Secret: " azure_client_secret
        echo
        read -rp "Enter Azure Tenant ID: " azure_tenant_id
        read -rp "Enter Azure Subscription ID (optional): " azure_subscription_id
        
        # Export variables for current session
        export AZURE_CLIENT_ID="$azure_client_id"
        export AZURE_CLIENT_SECRET="$azure_client_secret"
        export AZURE_TENANT_ID="$azure_tenant_id"
        
        if [[ -n "$azure_subscription_id" ]]; then
            export AZURE_SUBSCRIPTION_ID="$azure_subscription_id"
        fi
        
        log_success "Azure environment credentials configured"
    else
        log_info "Azure environment credentials should be set via environment variables:"
        log_info "  export AZURE_CLIENT_ID=your-client-id"
        log_info "  export AZURE_CLIENT_SECRET=your-client-secret"
        log_info "  export AZURE_TENANT_ID=your-tenant-id"
        log_info "  export AZURE_SUBSCRIPTION_ID=your-subscription-id"
    fi
}

# Validate all credentials
validate_credentials() {
    local aws_valid=false
    local azure_valid=false
    local validation_errors=()
    
    if [[ "$CLOUD_PROVIDER" == "aws" || "$CLOUD_PROVIDER" == "both" ]]; then
        log_info "Validating AWS credentials..."
        
        local aws_method
        aws_method=$(auto_detect_aws_credentials)
        
        case "$aws_method" in
            instance_profile)
                aws_valid=true
                log_success "AWS credentials: Instance Profile"
                ;;
            environment)
                aws_valid=true
                log_success "AWS credentials: Environment Variables"
                ;;
            profile)
                aws_valid=true
                log_success "AWS credentials: Profile ($AWS_PROFILE)"
                ;;
            role)
                aws_valid=true
                log_success "AWS credentials: IAM Role ($AWS_ROLE_ARN)"
                ;;
            none)
                validation_errors+=("No valid AWS credentials found")
                ;;
        esac
    fi
    
    if [[ "$CLOUD_PROVIDER" == "azure" || "$CLOUD_PROVIDER" == "both" ]]; then
        log_info "Validating Azure credentials..."
        
        local azure_method
        azure_method=$(auto_detect_azure_credentials)
        
        case "$azure_method" in
            managed_identity)
                azure_valid=true
                log_success "Azure credentials: Managed Identity"
                ;;
            cli)
                azure_valid=true
                log_success "Azure credentials: Azure CLI"
                ;;
            environment)
                azure_valid=true
                log_success "Azure credentials: Environment Variables"
                ;;
            none)
                validation_errors+=("No valid Azure credentials found")
                ;;
        esac
    fi
    
    # Report validation results
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Credential validation failed:"
        for error in "${validation_errors[@]}"; do
            log_error "  - $error"
        done
        return 1
    else
        log_success "All required credentials are valid"
        return 0
    fi
}

# Setup credentials based on method
setup_credentials() {
    if [[ "$VALIDATE_ONLY" == "true" ]]; then
        log_info "Validation-only mode, skipping credential setup"
        return 0
    fi
    
    log_info "Setting up credentials using method: $CREDENTIAL_METHOD"
    
    case "$CREDENTIAL_METHOD" in
        auto)
            log_info "Auto-detection mode - credentials should already be configured"
            ;;
        env|interactive)
            if [[ "$CLOUD_PROVIDER" == "aws" || "$CLOUD_PROVIDER" == "both" ]]; then
                setup_aws_env_credentials
            fi
            
            if [[ "$CLOUD_PROVIDER" == "azure" || "$CLOUD_PROVIDER" == "both" ]]; then
                setup_azure_env_credentials
            fi
            ;;
        role)
            log_info "Role-based authentication - ensure IAM roles/managed identities are configured"
            ;;
        file)
            log_info "File-based authentication - ensure credential files are configured"
            log_info "AWS: ~/.aws/credentials and ~/.aws/config"
            log_info "Azure: ~/.azure/credentials"
            ;;
    esac
}

# Generate credential configuration examples
generate_examples() {
    log_info "Credential configuration examples:"
    echo
    
    if [[ "$CLOUD_PROVIDER" == "aws" || "$CLOUD_PROVIDER" == "both" ]]; then
        echo "# AWS Environment Variables"
        echo "export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE"
        echo "export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
        echo "export AWS_REGION=us-east-1"
        echo
        echo "# AWS Profile"
        echo "export AWS_PROFILE=security-scanner"
        echo
        echo "# AWS Role"
        echo "export AWS_ROLE_ARN=arn:aws:iam::123456789012:role/SecurityScannerRole"
        echo
    fi
    
    if [[ "$CLOUD_PROVIDER" == "azure" || "$CLOUD_PROVIDER" == "both" ]]; then
        echo "# Azure Environment Variables"
        echo "export AZURE_CLIENT_ID=12345678-1234-1234-1234-123456789012"
        echo "export AZURE_CLIENT_SECRET=your-client-secret"
        echo "export AZURE_TENANT_ID=12345678-1234-1234-1234-123456789012"
        echo "export AZURE_SUBSCRIPTION_ID=12345678-1234-1234-1234-123456789012"
        echo
        echo "# Alternative Azure Environment Variables"
        echo "export ARM_CLIENT_ID=12345678-1234-1234-1234-123456789012"
        echo "export ARM_CLIENT_SECRET=your-client-secret"
        echo "export ARM_TENANT_ID=12345678-1234-1234-1234-123456789012"
        echo "export ARM_SUBSCRIPTION_ID=12345678-1234-1234-1234-123456789012"
        echo
    fi
}

# Security checks
perform_security_checks() {
    log_info "Performing security checks..."
    
    # Check for hardcoded credentials in environment
    local security_issues=()
    
    # Check if we're in a secure environment
    if ! is_ci_environment && ! is_cloud_environment; then
        log_warn "Running in local development environment"
        log_info "Ensure credentials are not committed to version control"
    fi
    
    # Check for common credential patterns in environment
    if env | grep -E "(AWS_ACCESS_KEY_ID|AZURE_CLIENT_SECRET)" | grep -E "(AKIA[0-9A-Z]{16}|[0-9a-zA-Z~._-]{34,40})" >/dev/null 2>&1; then
        security_issues+=("Potential hardcoded credentials detected in environment")
    fi
    
    # Report security issues
    if [[ ${#security_issues[@]} -gt 0 ]]; then
        log_warn "Security issues detected:"
        for issue in "${security_issues[@]}"; do
            log_warn "  - $issue"
        done
    else
        log_success "No security issues detected"
    fi
}

# Main execution
main() {
    parse_args "$@"
    validate_args
    
    log_info "Multi-Cloud Credential Management"
    log_info "Cloud Provider: $CLOUD_PROVIDER"
    log_info "Credential Method: $CREDENTIAL_METHOD"
    log_info "Validate Only: $VALIDATE_ONLY"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi
    
    # Perform security checks
    perform_security_checks
    
    # Setup credentials if not validation-only
    if [[ "$VALIDATE_ONLY" != "true" ]]; then
        setup_credentials
    fi
    
    # Validate credentials
    if validate_credentials; then
        log_success "Credential setup completed successfully"
        
        if [[ "$VERBOSE" == "true" ]]; then
            generate_examples
        fi
        
        exit 0
    else
        log_error "Credential validation failed"
        
        if [[ "$CREDENTIAL_METHOD" == "auto" ]]; then
            log_info "Try running with --method interactive to configure credentials manually"
        fi
        
        generate_examples
        exit 1
    fi
}

# Run main function
main "$@"