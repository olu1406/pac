#!/bin/bash

# Multi-Cloud Security Policy System - Control Scaffolding Script
# Creates new security controls with proper structure and metadata
# Usage: ./scripts/new-control.sh [options]

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POLICIES_DIR="${PROJECT_ROOT}/policies"
METADATA_FILE="${POLICIES_DIR}/control_metadata.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CLOUD_PROVIDER=""
DOMAIN=""
CONTROL_NUMBER=""
TITLE=""
SEVERITY=""
FRAMEWORKS=""
DESCRIPTION=""
REMEDIATION=""
OPTIONAL=false
CATEGORY=""
PREREQUISITES=""
IMPACT=""
INTERACTIVE=true

# Valid options
VALID_CLOUDS=("aws" "azure" "multi")
VALID_DOMAINS=("identity" "networking" "logging" "data" "governance")
VALID_SEVERITIES=("LOW" "MEDIUM" "HIGH" "CRITICAL")
VALID_CATEGORIES=("strict" "experimental" "environment-specific")

# Framework prefixes - using a more portable approach
get_framework_prefix() {
    case "$1" in
        "nist") echo "NIST-800-53" ;;
        "cis-aws") echo "CIS-AWS" ;;
        "cis-azure") echo "CIS-Azure" ;;
        "iso") echo "ISO-27001" ;;
        *) echo "$1" ;;
    esac
}

# Help function
show_help() {
    cat << EOF
Multi-Cloud Security Policy Control Scaffolding Script

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Creates new security controls with proper structure and metadata.
    Can be run interactively or with command-line arguments.

OPTIONS:
    -c, --cloud PROVIDER        Cloud provider (aws|azure|multi)
    -d, --domain DOMAIN         Security domain (identity|networking|logging|data|governance)
    -n, --number NUMBER         Control number (e.g., 001, 002)
    -t, --title TITLE           Control title (quoted string)
    -s, --severity LEVEL        Severity level (LOW|MEDIUM|HIGH|CRITICAL)
    -f, --frameworks LIST       Framework mappings (comma-separated, e.g., "nist:AC-2,cis-aws:1.1")
    --description DESC          Control description (quoted string)
    --remediation REM           Remediation guidance (quoted string)
    --optional                  Create as optional control (default: false)
    --category CATEGORY         Optional control category (strict|experimental|environment-specific)
    --prerequisites PREREQ      Prerequisites for optional controls (quoted string)
    --impact IMPACT             Impact description for optional controls (quoted string)
    --non-interactive           Run without interactive prompts
    -h, --help                  Show this help message

EXAMPLES:
    # Interactive mode (default)
    $0

    # Create AWS IAM control non-interactively
    $0 --cloud aws --domain identity --number 010 \\
       --title "IAM users must have access keys rotated regularly" \\
       --severity HIGH \\
       --frameworks "nist:AC-2,cis-aws:1.4" \\
       --description "Enforces regular rotation of IAM access keys" \\
       --remediation "Configure access key rotation policy" \\
       --non-interactive

    # Create optional Azure control
    $0 --cloud azure --domain networking --number 020 \\
       --title "Require private endpoints for all PaaS services" \\
       --severity MEDIUM \\
       --frameworks "nist:AC-4,cis-azure:6.1" \\
       --optional \\
       --category strict \\
       --prerequisites "Private DNS zones configured" \\
       --impact "May require network architecture changes" \\
       --non-interactive

FRAMEWORK MAPPING FORMAT:
    Use the format "prefix:control" where prefix is:
    - nist: NIST 800-53 controls (e.g., nist:AC-2)
    - cis-aws: CIS AWS Benchmark (e.g., cis-aws:1.1)
    - cis-azure: CIS Azure Benchmark (e.g., cis-azure:1.1)
    - iso: ISO 27001 controls (e.g., iso:A.9.2.1)

    Multiple frameworks: "nist:AC-2,cis-aws:1.1,iso:A.9.2.1"

CONTROL ID FORMAT:
    Standard controls: [DOMAIN]-[NUMBER] (e.g., IAM-010, NET-020)
    Optional controls: OPT-[CLOUD]-[DOMAIN]-[NUMBER] (e.g., OPT-AWS-IAM-010)

FILES CREATED:
    - Control policy file in appropriate directory
    - Updated control metadata in control_metadata.json
    - Test template (if test directory exists)

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Validation functions
validate_cloud() {
    local cloud="$1"
    for valid in "${VALID_CLOUDS[@]}"; do
        if [[ "$cloud" == "$valid" ]]; then
            return 0
        fi
    done
    return 1
}

validate_domain() {
    local domain="$1"
    for valid in "${VALID_DOMAINS[@]}"; do
        if [[ "$domain" == "$valid" ]]; then
            return 0
        fi
    done
    return 1
}

validate_severity() {
    local severity="$1"
    for valid in "${VALID_SEVERITIES[@]}"; do
        if [[ "$severity" == "$valid" ]]; then
            return 0
        fi
    done
    return 1
}

validate_category() {
    local category="$1"
    for valid in "${VALID_CATEGORIES[@]}"; do
        if [[ "$category" == "$valid" ]]; then
            return 0
        fi
    done
    return 1
}

validate_control_number() {
    local number="$1"
    if [[ ! "$number" =~ ^[0-9]{3}$ ]]; then
        return 1
    fi
    return 0
}

# Check if control ID already exists
check_control_exists() {
    local control_id="$1"
    if [[ -f "$METADATA_FILE" ]] && grep -q "\"$control_id\":" "$METADATA_FILE"; then
        return 0
    fi
    return 1
}

# Get next available control number for domain
get_next_control_number() {
    local cloud="$1"
    local domain="$2"
    local optional="$3"
    
    local prefix
    if [[ "$optional" == "true" ]]; then
        prefix="OPT-$(echo "$cloud" | tr '[:lower:]' '[:upper:]')-$(echo "$domain" | tr '[:lower:]' '[:upper:]')"
    else
        case "$domain" in
            "identity") prefix="IAM" ;;
            "networking") prefix="NET" ;;
            "logging") prefix="LOG" ;;
            "data") prefix="DATA" ;;
            "governance") prefix="GOV" ;;
            *) prefix="$(echo "$domain" | tr '[:lower:]' '[:upper:]')" ;;
        esac
    fi
    
    local max_num=0
    if [[ -f "$METADATA_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ \"($prefix-[0-9]{3})\" ]]; then
                local num="${BASH_REMATCH[1]##*-}"
                if (( num > max_num )); then
                    max_num=$num
                fi
            fi
        done < "$METADATA_FILE"
    fi
    
    printf "%03d" $((max_num + 1))
}

# Parse framework mappings
parse_frameworks() {
    local frameworks_input="$1"
    local frameworks_json=""
    local nist_controls=""
    local cis_aws_controls=""
    local cis_azure_controls=""
    local iso_controls=""
    
    IFS=',' read -ra FRAMEWORK_PAIRS <<< "$frameworks_input"
    for pair in "${FRAMEWORK_PAIRS[@]}"; do
        IFS=':' read -ra PARTS <<< "$pair"
        if [[ ${#PARTS[@]} -eq 2 ]]; then
            local prefix="${PARTS[0]}"
            local control="${PARTS[1]}"
            
            case "$prefix" in
                "nist")
                    nist_controls+="\"$control\","
                    ;;
                "cis-aws")
                    cis_aws_controls+="\"$control\","
                    ;;
                "cis-azure")
                    cis_azure_controls+="\"$control\","
                    ;;
                "iso")
                    iso_controls+="\"$control\","
                    ;;
                *)
                    log_warning "Unknown framework prefix: $prefix"
                    ;;
            esac
        fi
    done
    
    # Build JSON object
    local json_parts=()
    [[ -n "$nist_controls" ]] && json_parts+=("\"nist_800_53\": [${nist_controls%,}]")
    [[ -n "$cis_aws_controls" ]] && json_parts+=("\"cis_aws\": [${cis_aws_controls%,}]")
    [[ -n "$cis_azure_controls" ]] && json_parts+=("\"cis_azure\": [${cis_azure_controls%,}]")
    [[ -n "$iso_controls" ]] && json_parts+=("\"iso_27001\": [${iso_controls%,}]")
    
    local IFS=', '
    echo "{${json_parts[*]}}"
}

# Interactive input functions
prompt_cloud() {
    while true; do
        echo -n "Cloud provider (aws/azure/multi): "
        read -r CLOUD_PROVIDER
        if validate_cloud "$CLOUD_PROVIDER"; then
            break
        else
            log_error "Invalid cloud provider. Choose from: ${VALID_CLOUDS[*]}"
        fi
    done
}

prompt_domain() {
    while true; do
        echo -n "Security domain (identity/networking/logging/data/governance): "
        read -r DOMAIN
        if validate_domain "$DOMAIN"; then
            break
        else
            log_error "Invalid domain. Choose from: ${VALID_DOMAINS[*]}"
        fi
    done
}

prompt_control_number() {
    local suggested
    suggested=$(get_next_control_number "$CLOUD_PROVIDER" "$DOMAIN" "$OPTIONAL")
    
    while true; do
        echo -n "Control number (3 digits, suggested: $suggested): "
        read -r CONTROL_NUMBER
        if [[ -z "$CONTROL_NUMBER" ]]; then
            CONTROL_NUMBER="$suggested"
        fi
        
        if validate_control_number "$CONTROL_NUMBER"; then
            local control_id
            if [[ "$OPTIONAL" == "true" ]]; then
                control_id="OPT-$(echo "$CLOUD_PROVIDER" | tr '[:lower:]' '[:upper:]')-$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')-$CONTROL_NUMBER"
            else
                case "$DOMAIN" in
                    "identity") control_id="IAM-$CONTROL_NUMBER" ;;
                    "networking") control_id="NET-$CONTROL_NUMBER" ;;
                    "logging") control_id="LOG-$CONTROL_NUMBER" ;;
                    "data") control_id="DATA-$CONTROL_NUMBER" ;;
                    "governance") control_id="GOV-$CONTROL_NUMBER" ;;
                    *) control_id="$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')-$CONTROL_NUMBER" ;;
                esac
            fi
            
            if check_control_exists "$control_id"; then
                log_error "Control ID $control_id already exists. Choose a different number."
            else
                break
            fi
        else
            log_error "Invalid control number. Must be 3 digits (e.g., 001, 010, 123)."
        fi
    done
}

prompt_title() {
    while true; do
        echo -n "Control title: "
        read -r TITLE
        if [[ -n "$TITLE" ]]; then
            break
        else
            log_error "Title cannot be empty."
        fi
    done
}

prompt_severity() {
    while true; do
        echo -n "Severity level (LOW/MEDIUM/HIGH/CRITICAL): "
        read -r SEVERITY
        SEVERITY=$(echo "$SEVERITY" | tr '[:lower:]' '[:upper:]')
        if validate_severity "$SEVERITY"; then
            break
        else
            log_error "Invalid severity. Choose from: ${VALID_SEVERITIES[*]}"
        fi
    done
}

prompt_frameworks() {
    echo "Framework mappings (format: prefix:control, comma-separated)"
    echo "Available prefixes: nist, cis-aws, cis-azure, iso"
    echo "Example: nist:AC-2,cis-aws:1.1,iso:A.9.2.1"
    echo -n "Frameworks: "
    read -r FRAMEWORKS
    
    if [[ -z "$FRAMEWORKS" ]]; then
        log_error "At least one framework mapping is required."
        prompt_frameworks
    fi
}

prompt_description() {
    echo -n "Control description: "
    read -r DESCRIPTION
    if [[ -z "$DESCRIPTION" ]]; then
        log_error "Description cannot be empty."
        prompt_description
    fi
}

prompt_remediation() {
    echo -n "Remediation guidance: "
    read -r REMEDIATION
    if [[ -z "$REMEDIATION" ]]; then
        log_error "Remediation guidance cannot be empty."
        prompt_remediation
    fi
}

prompt_optional() {
    echo -n "Create as optional control? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        OPTIONAL=true
        
        echo -n "Category (strict/experimental/environment-specific): "
        read -r CATEGORY
        if [[ -n "$CATEGORY" ]] && ! validate_category "$CATEGORY"; then
            log_error "Invalid category. Choose from: ${VALID_CATEGORIES[*]}"
            CATEGORY=""
        fi
        
        echo -n "Prerequisites: "
        read -r PREREQUISITES
        
        echo -n "Impact description: "
        read -r IMPACT
    else
        OPTIONAL=false
    fi
}

# Generate control ID
generate_control_id() {
    if [[ "$OPTIONAL" == "true" ]]; then
        echo "OPT-$(echo "$CLOUD_PROVIDER" | tr '[:lower:]' '[:upper:]')-$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')-$CONTROL_NUMBER"
    else
        case "$DOMAIN" in
            "identity") echo "IAM-$CONTROL_NUMBER" ;;
            "networking") echo "NET-$CONTROL_NUMBER" ;;
            "logging") echo "LOG-$CONTROL_NUMBER" ;;
            "data") echo "DATA-$CONTROL_NUMBER" ;;
            "governance") echo "GOV-$CONTROL_NUMBER" ;;
            *) echo "$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')-$CONTROL_NUMBER" ;;
        esac
    fi
}

# Generate policy file path
generate_policy_path() {
    local control_id="$1"
    
    if [[ "$OPTIONAL" == "true" ]]; then
        echo "${POLICIES_DIR}/optional/${CLOUD_PROVIDER}_${DOMAIN}_${CONTROL_NUMBER}.rego"
    else
        echo "${POLICIES_DIR}/${CLOUD_PROVIDER}/${DOMAIN}/${DOMAIN}_policies.rego"
    fi
}

# Generate Rego package name
generate_package_name() {
    if [[ "$OPTIONAL" == "true" ]]; then
        echo "terraform.security.${CLOUD_PROVIDER}.optional.${DOMAIN}"
    else
        echo "terraform.security.${CLOUD_PROVIDER}.${DOMAIN}"
    fi
}

# Create control policy content
create_control_policy() {
    local control_id="$1"
    local package_name="$2"
    local frameworks_comment="$3"
    
    cat << EOF
# CONTROL: $control_id
# TITLE: $TITLE
# SEVERITY: $SEVERITY
# FRAMEWORKS: $frameworks_comment
# STATUS: ENABLED
$(if [[ "$OPTIONAL" == "true" ]]; then
    echo "# OPTIONAL: true"
    [[ -n "$CATEGORY" ]] && echo "# CATEGORY: $CATEGORY"
    [[ -n "$PREREQUISITES" ]] && echo "# PREREQUISITES: $PREREQUISITES"
    [[ -n "$IMPACT" ]] && echo "# IMPACT: $IMPACT"
fi)

package $package_name

import rego.v1

# TODO: Implement control logic
# Replace this template with your specific control implementation
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "REPLACE_WITH_TERRAFORM_RESOURCE_TYPE"
    
    # TODO: Add your control logic here
    # Example: Check if resource meets security requirements
    not meets_security_requirements(resource.values)
    
    msg := {
        "control_id": "$control_id",
        "severity": "$SEVERITY",
        "resource": resource.address,
        "message": "$DESCRIPTION",
        "remediation": "$REMEDIATION"
    }
}

# TODO: Implement helper function
# Replace with your specific validation logic
meets_security_requirements(resource_values) if {
    # Add your validation logic here
    # Example: Check if required security configuration is present
    resource_values.security_setting == "enabled"
}

# Additional control rules can be added below following the same pattern
# Each control should have a unique control_id and appropriate logic
EOF
}

# Create or update policy file
create_policy_file() {
    local control_id="$1"
    local policy_path="$2"
    local package_name="$3"
    local frameworks_comment="$4"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$policy_path")"
    
    if [[ "$OPTIONAL" == "true" ]] || [[ ! -f "$policy_path" ]]; then
        # Create new file for optional controls or if file doesn't exist
        create_control_policy "$control_id" "$package_name" "$frameworks_comment" > "$policy_path"
        log_success "Created policy file: $policy_path"
    else
        # Append to existing file for standard controls
        echo "" >> "$policy_path"
        create_control_policy "$control_id" "$package_name" "$frameworks_comment" >> "$policy_path"
        log_success "Appended control to existing policy file: $policy_path"
    fi
}

# Update control metadata
update_metadata() {
    local control_id="$1"
    local policy_path="$2"
    local frameworks_json="$3"
    
    # Create backup of metadata file
    if [[ -f "$METADATA_FILE" ]]; then
        cp "$METADATA_FILE" "${METADATA_FILE}.backup"
    fi
    
    # Prepare metadata entry
    local metadata_entry
    metadata_entry=$(cat << EOF
    "$control_id": {
      "title": "$TITLE",
      "severity": "$SEVERITY",
      "cloud_provider": "$CLOUD_PROVIDER",
      "domain": "$DOMAIN",
      "frameworks": $frameworks_json,
      "description": "$DESCRIPTION",
      "remediation": "$REMEDIATION",
      "policy_file": "$(python3 -c "import os; print(os.path.relpath('$policy_path', '$PROJECT_ROOT'))")"$(if [[ "$OPTIONAL" == "true" ]]; then
        echo ","
        echo "      \"optional\": true"
        [[ -n "$CATEGORY" ]] && echo "      \"category\": \"$CATEGORY\","
        [[ -n "$PREREQUISITES" ]] && echo "      \"prerequisites\": \"$PREREQUISITES\","
        [[ -n "$IMPACT" ]] && echo "      \"impact\": \"$IMPACT\""
      fi)
    }
EOF
)
    
    if [[ ! -f "$METADATA_FILE" ]]; then
        # Create new metadata file
        cat << EOF > "$METADATA_FILE"
{
  "metadata": {
    "version": "1.0.0",
    "last_updated": "$(date -I)",
    "total_controls": 1,
    "frameworks": ["NIST-800-53", "CIS", "ISO-27001"],
    "aws_controls": $(if [[ "$CLOUD_PROVIDER" == "aws" ]]; then echo 1; else echo 0; fi),
    "azure_controls": $(if [[ "$CLOUD_PROVIDER" == "azure" ]]; then echo 1; else echo 0; fi),
    "optional_controls": $(if [[ "$OPTIONAL" == "true" ]]; then echo 1; else echo 0; fi)
  },
  "controls": {
$metadata_entry
  }
}
EOF
    else
        # Update existing metadata file using a more robust approach
        local temp_file
        temp_file=$(mktemp)
        
        # Use Python to safely update the JSON
        python3 << EOF > "$temp_file"
import json
import sys

# Read existing metadata
with open("$METADATA_FILE", 'r') as f:
    data = json.load(f)

# Add new control
new_control = {
    "title": "$TITLE",
    "severity": "$SEVERITY", 
    "cloud_provider": "$CLOUD_PROVIDER",
    "domain": "$DOMAIN",
    "frameworks": $frameworks_json,
    "description": "$DESCRIPTION",
    "remediation": "$REMEDIATION",
    "policy_file": "$(python3 -c "import os; print(os.path.relpath('$policy_path', '$PROJECT_ROOT'))")"
}

$(if [[ "$OPTIONAL" == "true" ]]; then
    echo 'new_control["optional"] = True'
    [[ -n "$CATEGORY" ]] && echo "new_control[\"category\"] = \"$CATEGORY\""
    [[ -n "$PREREQUISITES" ]] && echo "new_control[\"prerequisites\"] = \"$PREREQUISITES\""
    [[ -n "$IMPACT" ]] && echo "new_control[\"impact\"] = \"$IMPACT\""
fi)

data["controls"]["$control_id"] = new_control

# Update metadata counters
total_controls = len(data["controls"])
aws_controls = sum(1 for c in data["controls"].values() if c.get("cloud_provider") == "aws")
azure_controls = sum(1 for c in data["controls"].values() if c.get("cloud_provider") == "azure")
optional_controls = sum(1 for c in data["controls"].values() if c.get("optional", False))

data["metadata"]["total_controls"] = total_controls
data["metadata"]["aws_controls"] = aws_controls
data["metadata"]["azure_controls"] = azure_controls
data["metadata"]["optional_controls"] = optional_controls
data["metadata"]["last_updated"] = "$(date -I)"

# Write updated JSON
json.dump(data, sys.stdout, indent=2)
EOF
        
        if [[ $? -eq 0 ]]; then
            mv "$temp_file" "$METADATA_FILE"
        else
            log_error "Failed to update metadata file"
            rm -f "$temp_file"
            return 1
        fi
    fi
    
    log_success "Updated control metadata: $METADATA_FILE"
}

# Validate generated files
validate_generated_files() {
    local control_id="$1"
    local policy_path="$2"
    
    # Check if policy file was created
    if [[ ! -f "$policy_path" ]]; then
        log_error "Policy file was not created: $policy_path"
        return 1
    fi
    
    # Check if control ID exists in policy file
    if ! grep -q "CONTROL: $control_id" "$policy_path"; then
        log_error "Control ID not found in policy file: $control_id"
        return 1
    fi
    
    # Check if metadata was updated
    if [[ -f "$METADATA_FILE" ]] && ! grep -q "\"$control_id\":" "$METADATA_FILE"; then
        log_error "Control not found in metadata file: $control_id"
        return 1
    fi
    
    # Validate JSON syntax of metadata file
    if ! python3 -m json.tool "$METADATA_FILE" > /dev/null 2>&1; then
        log_error "Invalid JSON syntax in metadata file"
        return 1
    fi
    
    log_success "All generated files validated successfully"
    return 0
}

# Main execution function
main() {
    log_info "Multi-Cloud Security Policy Control Scaffolding Script"
    echo
    
    # Interactive prompts if not provided via command line
    if [[ "$INTERACTIVE" == "true" ]]; then
        if [[ -z "$CLOUD_PROVIDER" ]]; then prompt_cloud; fi
        if [[ -z "$DOMAIN" ]]; then prompt_domain; fi
        if [[ -z "$OPTIONAL" ]]; then prompt_optional; fi
        if [[ -z "$CONTROL_NUMBER" ]]; then prompt_control_number; fi
        if [[ -z "$TITLE" ]]; then prompt_title; fi
        if [[ -z "$SEVERITY" ]]; then prompt_severity; fi
        if [[ -z "$FRAMEWORKS" ]]; then prompt_frameworks; fi
        if [[ -z "$DESCRIPTION" ]]; then prompt_description; fi
        if [[ -z "$REMEDIATION" ]]; then prompt_remediation; fi
    fi
    
    # Validate all inputs
    if ! validate_cloud "$CLOUD_PROVIDER"; then
        log_error "Invalid cloud provider: $CLOUD_PROVIDER"
        exit 1
    fi
    
    if ! validate_domain "$DOMAIN"; then
        log_error "Invalid domain: $DOMAIN"
        exit 1
    fi
    
    if ! validate_control_number "$CONTROL_NUMBER"; then
        log_error "Invalid control number: $CONTROL_NUMBER"
        exit 1
    fi
    
    if ! validate_severity "$SEVERITY"; then
        log_error "Invalid severity: $SEVERITY"
        exit 1
    fi
    
    if [[ "$OPTIONAL" == "true" ]] && [[ -n "$CATEGORY" ]] && ! validate_category "$CATEGORY"; then
        log_error "Invalid category: $CATEGORY"
        exit 1
    fi
    
    # Generate control components
    local control_id
    control_id=$(generate_control_id)
    
    # Check if control already exists
    if check_control_exists "$control_id"; then
        log_error "Control $control_id already exists"
        exit 1
    fi
    
    local policy_path
    policy_path=$(generate_policy_path "$control_id")
    
    local package_name
    package_name=$(generate_package_name)
    
    local frameworks_json
    frameworks_json=$(parse_frameworks "$FRAMEWORKS")
    
    local frameworks_comment
    frameworks_comment=$(echo "$FRAMEWORKS" | sed 's/nist:/NIST-800-53:/g; s/cis-aws:/CIS-AWS:/g; s/cis-azure:/CIS-Azure:/g; s/iso:/ISO-27001:/g')
    
    # Display summary
    echo
    log_info "Control Summary:"
    echo "  Control ID: $control_id"
    echo "  Title: $TITLE"
    echo "  Cloud Provider: $CLOUD_PROVIDER"
    echo "  Domain: $DOMAIN"
    echo "  Severity: $SEVERITY"
    echo "  Optional: $OPTIONAL"
    [[ "$OPTIONAL" == "true" && -n "$CATEGORY" ]] && echo "  Category: $CATEGORY"
    echo "  Policy File: $policy_path"
    echo "  Package: $package_name"
    echo
    
    # Confirm creation
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo -n "Create this control? (Y/n): "
        read -r confirm
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            log_info "Control creation cancelled"
            exit 0
        fi
    fi
    
    # Create files
    log_info "Creating control files..."
    
    create_policy_file "$control_id" "$policy_path" "$package_name" "$frameworks_comment"
    update_metadata "$control_id" "$policy_path" "$frameworks_json"
    
    # Validate generated files
    if validate_generated_files "$control_id" "$policy_path"; then
        echo
        log_success "Control $control_id created successfully!"
        echo
        log_info "Next steps:"
        echo "  1. Edit the policy file to implement the control logic: $policy_path"
        echo "  2. Replace TODO comments with actual implementation"
        echo "  3. Test the control with example Terraform configurations"
        echo "  4. Add the control to your CI/CD pipeline"
        echo "  5. Update documentation if needed"
        
        if [[ "$OPTIONAL" == "true" ]]; then
            echo
            log_info "Optional Control Notes:"
            echo "  - This control is disabled by default"
            echo "  - Users can enable it by uncommenting the control block"
            echo "  - Consider adding it to the controls selection guide"
        fi
    else
        log_error "Control creation failed validation"
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--cloud)
            CLOUD_PROVIDER="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -n|--number)
            CONTROL_NUMBER="$2"
            shift 2
            ;;
        -t|--title)
            TITLE="$2"
            shift 2
            ;;
        -s|--severity)
            SEVERITY=$(echo "$2" | tr '[:lower:]' '[:upper:]')
            shift 2
            ;;
        -f|--frameworks)
            FRAMEWORKS="$2"
            shift 2
            ;;
        --description)
            DESCRIPTION="$2"
            shift 2
            ;;
        --remediation)
            REMEDIATION="$2"
            shift 2
            ;;
        --optional)
            OPTIONAL=true
            shift
            ;;
        --category)
            CATEGORY="$2"
            shift 2
            ;;
        --prerequisites)
            PREREQUISITES="$2"
            shift 2
            ;;
        --impact)
            IMPACT="$2"
            shift 2
            ;;
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if all required arguments are provided for non-interactive mode
if [[ "$INTERACTIVE" == "false" ]]; then
    missing_args=()
    
    [[ -z "$CLOUD_PROVIDER" ]] && missing_args+=("--cloud")
    [[ -z "$DOMAIN" ]] && missing_args+=("--domain")
    [[ -z "$CONTROL_NUMBER" ]] && missing_args+=("--number")
    [[ -z "$TITLE" ]] && missing_args+=("--title")
    [[ -z "$SEVERITY" ]] && missing_args+=("--severity")
    [[ -z "$FRAMEWORKS" ]] && missing_args+=("--frameworks")
    [[ -z "$DESCRIPTION" ]] && missing_args+=("--description")
    [[ -z "$REMEDIATION" ]] && missing_args+=("--remediation")
    
    if [[ ${#missing_args[@]} -gt 0 ]]; then
        log_error "Missing required arguments for non-interactive mode: ${missing_args[*]}"
        echo
        show_help
        exit 1
    fi
fi

# Run main function
main