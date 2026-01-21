#!/bin/bash

# Terraform Plan Generation Script
# Generates Terraform plans and converts them to JSON format for policy validation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/reports}"

# Default configuration
TERRAFORM_DIR="${TERRAFORM_DIR:-$PWD}"
WORKSPACE="${WORKSPACE:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
PLAN_FILE="${PLAN_FILE:-}"
INIT_UPGRADE="${INIT_UPGRADE:-false}"
VERBOSE="${VERBOSE:-false}"

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

Generate Terraform plans and convert to JSON format for policy validation.

OPTIONS:
    -d, --terraform-dir DIR     Terraform directory to process (default: current directory)
    -w, --workspace WORKSPACE   Terraform workspace to use (optional)
    -o, --output FILE           Output JSON file path (default: auto-generated)
    -p, --plan-file FILE        Plan file path (default: auto-generated)
    -u, --init-upgrade          Run terraform init with -upgrade flag
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                                          # Generate plan for current directory
    $0 -d ./infrastructure                      # Generate plan for specific directory
    $0 -d ./terraform -w production             # Use specific workspace
    $0 -d ./terraform -o /tmp/plan.json         # Specify output file
    $0 -d ./terraform -u                        # Upgrade providers during init

ENVIRONMENT VARIABLES:
    TERRAFORM_DIR               Override default terraform directory
    WORKSPACE                   Override default workspace
    OUTPUT_FILE                 Override default output file
    PLAN_FILE                   Override default plan file
    INIT_UPGRADE                Enable init upgrade (true/false)
    VERBOSE                     Enable verbose output (true/false)
    REPORTS_DIR                 Override reports directory

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--terraform-dir)
                TERRAFORM_DIR="$2"
                shift 2
                ;;
            -w|--workspace)
                WORKSPACE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -p|--plan-file)
                PLAN_FILE="$2"
                shift 2
                ;;
            -u|--init-upgrade)
                INIT_UPGRADE="true"
                shift
                ;;
            -v|--verbose)
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

# Validate dependencies
check_dependencies() {
    if ! command -v terraform &> /dev/null; then
        log_error "terraform command not found. Please install Terraform."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq command not found. Please install jq for JSON processing."
        exit 1
    fi
    
    log_debug "Dependencies validated successfully"
}

# Validate terraform directory
validate_terraform_dir() {
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory does not exist: $TERRAFORM_DIR"
        exit 1
    fi
    
    # Check for Terraform files
    local tf_files_count
    tf_files_count=$(find "$TERRAFORM_DIR" -maxdepth 1 -name "*.tf" -type f | wc -l)
    
    if [[ $tf_files_count -eq 0 ]]; then
        # Check subdirectories for Terraform files
        local tf_files_recursive
        tf_files_recursive=$(find "$TERRAFORM_DIR" -name "*.tf" -type f | wc -l)
        
        if [[ $tf_files_recursive -eq 0 ]]; then
            log_error "No Terraform files found in directory: $TERRAFORM_DIR"
            exit 1
        else
            log_warn "No Terraform files in root directory, but found $tf_files_recursive files in subdirectories"
        fi
    else
        log_debug "Found $tf_files_count Terraform files in directory"
    fi
}

# Get terraform version for compatibility checks
get_terraform_version() {
    local version_output
    version_output=$(terraform version -json 2>/dev/null || terraform version)
    
    if command -v jq &> /dev/null && [[ "$version_output" =~ ^\{ ]]; then
        echo "$version_output" | jq -r '.terraform_version'
    else
        echo "$version_output" | head -n1 | sed 's/Terraform v//' | awk '{print $1}'
    fi
}

# Initialize terraform
init_terraform() {
    local terraform_dir="$1"
    
    log_info "Initializing Terraform in directory: $terraform_dir"
    
    cd "$terraform_dir"
    
    # Check if already initialized
    if [[ -d ".terraform" ]] && [[ "$INIT_UPGRADE" != "true" ]]; then
        log_debug "Terraform already initialized, skipping init"
        return 0
    fi
    
    # Prepare init command
    local init_cmd="terraform init -input=false -no-color"
    
    if [[ "$INIT_UPGRADE" == "true" ]]; then
        init_cmd="$init_cmd -upgrade"
        log_info "Running terraform init with upgrade flag"
    fi
    
    # Run terraform init
    if [[ "$VERBOSE" == "true" ]]; then
        if ! $init_cmd; then
            log_error "Failed to initialize Terraform"
            return 1
        fi
    else
        if ! $init_cmd > /dev/null 2>&1; then
            log_error "Failed to initialize Terraform"
            log_info "Run with -v flag for detailed error output"
            return 1
        fi
    fi
    
    log_success "Terraform initialized successfully"
    return 0
}

# Select or create workspace
manage_workspace() {
    local workspace="$1"
    
    if [[ -z "$workspace" ]]; then
        log_debug "No workspace specified, using default"
        return 0
    fi
    
    log_info "Managing Terraform workspace: $workspace"
    
    # List existing workspaces
    local existing_workspaces
    existing_workspaces=$(terraform workspace list 2>/dev/null | sed 's/^[* ] //' | tr -d ' ')
    
    # Check if workspace exists
    if echo "$existing_workspaces" | grep -q "^$workspace$"; then
        log_debug "Workspace '$workspace' exists, selecting it"
        if ! terraform workspace select "$workspace" > /dev/null 2>&1; then
            log_error "Failed to select workspace: $workspace"
            return 1
        fi
    else
        log_info "Workspace '$workspace' does not exist, creating it"
        if ! terraform workspace new "$workspace" > /dev/null 2>&1; then
            log_error "Failed to create workspace: $workspace"
            return 1
        fi
    fi
    
    # Verify current workspace
    local current_workspace
    current_workspace=$(terraform workspace show 2>/dev/null)
    
    if [[ "$current_workspace" != "$workspace" ]]; then
        log_error "Failed to switch to workspace: $workspace (current: $current_workspace)"
        return 1
    fi
    
    log_success "Using workspace: $workspace"
    return 0
}

# Generate terraform plan
generate_plan() {
    local terraform_dir="$1"
    local plan_file="$2"
    
    log_info "Generating Terraform plan..."
    
    cd "$terraform_dir"
    
    # Prepare plan command
    local plan_cmd="terraform plan -input=false -no-color -out=$plan_file"
    
    # Add detailed exit code for better error handling
    local plan_exit_code=0
    
    if [[ "$VERBOSE" == "true" ]]; then
        $plan_cmd || plan_exit_code=$?
    else
        $plan_cmd > /dev/null 2>&1 || plan_exit_code=$?
    fi
    
    # Handle different exit codes
    case $plan_exit_code in
        0)
            log_success "Terraform plan generated successfully"
            ;;
        1)
            log_error "Terraform plan failed with errors"
            return 1
            ;;
        2)
            log_info "Terraform plan completed with changes detected"
            ;;
        *)
            log_error "Terraform plan failed with unexpected exit code: $plan_exit_code"
            return 1
            ;;
    esac
    
    # Verify plan file was created
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file was not created: $plan_file"
        return 1
    fi
    
    return 0
}

# Convert plan to JSON
convert_plan_to_json() {
    local terraform_dir="$1"
    local plan_file="$2"
    local output_file="$3"
    
    log_info "Converting plan to JSON format..."
    
    cd "$terraform_dir"
    
    # Verify plan file exists
    if [[ ! -f "$plan_file" ]]; then
        log_error "Plan file not found: $plan_file"
        return 1
    fi
    
    # Convert to JSON
    if [[ "$VERBOSE" == "true" ]]; then
        if ! terraform show -json "$plan_file" > "$output_file"; then
            log_error "Failed to convert plan to JSON"
            return 1
        fi
    else
        if ! terraform show -json "$plan_file" > "$output_file" 2>/dev/null; then
            log_error "Failed to convert plan to JSON"
            log_info "Run with -v flag for detailed error output"
            return 1
        fi
    fi
    
    # Verify JSON file was created and is valid
    if [[ ! -f "$output_file" ]]; then
        log_error "JSON file was not created: $output_file"
        return 1
    fi
    
    if ! jq empty "$output_file" 2>/dev/null; then
        log_error "Generated JSON file is invalid: $output_file"
        return 1
    fi
    
    log_success "Plan converted to JSON: $output_file"
    return 0
}

# Generate file paths
generate_file_paths() {
    local terraform_dir="$1"
    local workspace="$2"
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Generate unique file names based on directory and workspace
    local dir_name
    dir_name=$(basename "$terraform_dir")
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    local file_suffix=""
    if [[ -n "$workspace" ]]; then
        file_suffix="_${workspace}"
    fi
    
    # Set default plan file if not specified
    if [[ -z "$PLAN_FILE" ]]; then
        PLAN_FILE="$REPORTS_DIR/terraform_${dir_name}${file_suffix}_${timestamp}.tfplan"
    fi
    
    # Set default output file if not specified
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="$REPORTS_DIR/terraform_${dir_name}${file_suffix}_${timestamp}.json"
    fi
    
    log_debug "Plan file: $PLAN_FILE"
    log_debug "Output file: $OUTPUT_FILE"
}

# Cleanup function
cleanup() {
    # Remove plan file if verbose mode is disabled
    if [[ "$VERBOSE" != "true" ]] && [[ -n "$PLAN_FILE" ]] && [[ -f "$PLAN_FILE" ]]; then
        rm -f "$PLAN_FILE"
        log_debug "Cleaned up plan file: $PLAN_FILE"
    fi
}

# Process multiple terraform directories
process_multiple_directories() {
    local base_dir="$1"
    local results=()
    
    log_info "Scanning for Terraform directories in: $base_dir"
    
    # Find directories containing .tf files
    local terraform_dirs
    terraform_dirs=$(find "$base_dir" -name "*.tf" -type f -exec dirname {} \; | sort -u)
    
    if [[ -z "$terraform_dirs" ]]; then
        log_error "No Terraform directories found in: $base_dir"
        return 1
    fi
    
    local dir_count
    dir_count=$(echo "$terraform_dirs" | wc -l)
    log_info "Found $dir_count Terraform directories"
    
    # Process each directory
    while IFS= read -r terraform_dir; do
        log_info "Processing directory: $terraform_dir"
        
        # Generate file paths for this directory
        local original_terraform_dir="$TERRAFORM_DIR"
        local original_plan_file="$PLAN_FILE"
        local original_output_file="$OUTPUT_FILE"
        
        TERRAFORM_DIR="$terraform_dir"
        PLAN_FILE=""
        OUTPUT_FILE=""
        
        generate_file_paths "$terraform_dir" "$WORKSPACE"
        
        # Process this directory
        if process_single_directory "$terraform_dir"; then
            results+=("$OUTPUT_FILE")
            log_success "Successfully processed: $terraform_dir"
        else
            log_error "Failed to process: $terraform_dir"
        fi
        
        # Restore original values
        TERRAFORM_DIR="$original_terraform_dir"
        PLAN_FILE="$original_plan_file"
        OUTPUT_FILE="$original_output_file"
        
    done <<< "$terraform_dirs"
    
    # Output results
    if [[ ${#results[@]} -gt 0 ]]; then
        log_success "Generated ${#results[@]} plan JSON files:"
        printf '%s\n' "${results[@]}"
        return 0
    else
        log_error "No plans were generated successfully"
        return 1
    fi
}

# Process single terraform directory
process_single_directory() {
    local terraform_dir="$1"
    
    # Validate directory
    if ! validate_terraform_dir; then
        return 1
    fi
    
    # Initialize terraform
    if ! init_terraform "$terraform_dir"; then
        return 1
    fi
    
    # Manage workspace
    if ! manage_workspace "$WORKSPACE"; then
        return 1
    fi
    
    # Generate plan
    if ! generate_plan "$terraform_dir" "$PLAN_FILE"; then
        return 1
    fi
    
    # Convert to JSON
    if ! convert_plan_to_json "$terraform_dir" "$PLAN_FILE" "$OUTPUT_FILE"; then
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    parse_args "$@"
    
    # Convert terraform directory to absolute path if relative
    if [[ ! "$TERRAFORM_DIR" = /* ]]; then
        TERRAFORM_DIR="$(pwd)/$TERRAFORM_DIR"
    fi
    
    log_info "Starting Terraform plan generation"
    log_info "Terraform Directory: $TERRAFORM_DIR"
    
    if [[ -n "$WORKSPACE" ]]; then
        log_info "Workspace: $WORKSPACE"
    fi
    
    # Check dependencies
    check_dependencies
    
    # Get terraform version
    local tf_version
    tf_version=$(get_terraform_version)
    log_info "Terraform Version: $tf_version"
    
    # Generate file paths
    generate_file_paths "$TERRAFORM_DIR" "$WORKSPACE"
    
    # Check if we should process multiple directories
    if [[ -d "$TERRAFORM_DIR" ]]; then
        local tf_files_in_root
        tf_files_in_root=$(find "$TERRAFORM_DIR" -maxdepth 1 -name "*.tf" -type f | wc -l)
        
        if [[ $tf_files_in_root -eq 0 ]]; then
            # No .tf files in root, scan subdirectories
            process_multiple_directories "$TERRAFORM_DIR"
        else
            # Process single directory
            process_single_directory "$TERRAFORM_DIR"
            echo "$OUTPUT_FILE"
        fi
    else
        log_error "Invalid terraform directory: $TERRAFORM_DIR"
        exit 1
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"