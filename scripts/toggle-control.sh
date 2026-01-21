#!/bin/bash

# Control Toggle Script for Multi-Cloud Security Policy System
# Enables/disables controls by commenting/uncommenting control blocks in Rego policies

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="$PROJECT_ROOT/policies"
CONTROL_METADATA="$POLICIES_DIR/control_metadata.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND CONTROL_ID

Control Toggle Script - Enable/disable security controls

COMMANDS:
    enable CONTROL_ID    Enable a control by uncommenting its block
    disable CONTROL_ID   Disable a control by commenting its block
    status CONTROL_ID    Show current status of a control
    list                 List all controls and their status

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -n, --dry-run       Show what would be changed without making changes

EXAMPLES:
    $0 enable IAM-001           # Enable IAM-001 control
    $0 disable NET-002          # Disable NET-002 control
    $0 status DATA-001          # Show status of DATA-001 control
    $0 list                     # List all controls
    $0 --dry-run enable IAM-003 # Preview enabling IAM-003

CONTROL BLOCK FORMAT:
Controls are identified by comment blocks starting with "# CONTROL: CONTROL_ID"
and ending with the next control block or end of file.

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1" >&2
    fi
}

# Check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    for tool in jq sed grep; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing tools and try again"
        exit 1
    fi
}

# Validate project structure
validate_project_structure() {
    if [[ ! -d "$POLICIES_DIR" ]]; then
        log_error "Policies directory not found: $POLICIES_DIR"
        exit 1
    fi
    
    if [[ ! -f "$CONTROL_METADATA" ]]; then
        log_error "Control metadata file not found: $CONTROL_METADATA"
        exit 1
    fi
}

# Get control information from metadata
get_control_info() {
    local control_id="$1"
    
    if ! jq -e ".controls.\"$control_id\"" "$CONTROL_METADATA" &> /dev/null; then
        log_error "Control $control_id not found in metadata"
        return 1
    fi
    
    jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA"
}

# Get policy file path for a control
get_policy_file() {
    local control_id="$1"
    local control_info
    
    control_info=$(get_control_info "$control_id") || return 1
    echo "$control_info" | jq -r '.policy_file'
}

# Find control block in policy file
find_control_block() {
    local policy_file="$1"
    local control_id="$2"
    
    if [[ ! -f "$PROJECT_ROOT/$policy_file" ]]; then
        log_error "Policy file not found: $PROJECT_ROOT/$policy_file"
        return 1
    fi
    
    # Find line numbers for control block
    local start_line end_line
    start_line=$(grep -n "^# CONTROL: $control_id$" "$PROJECT_ROOT/$policy_file" | cut -d: -f1)
    
    if [[ -z "$start_line" ]]; then
        log_error "Control $control_id not found in policy file: $policy_file"
        return 1
    fi
    
    # Find end of control block (next control or end of file)
    end_line=$(tail -n +$((start_line + 1)) "$PROJECT_ROOT/$policy_file" | grep -n "^# CONTROL:" | head -1 | cut -d: -f1)
    
    if [[ -n "$end_line" ]]; then
        end_line=$((start_line + end_line - 1))
    else
        end_line=$(wc -l < "$PROJECT_ROOT/$policy_file")
    fi
    
    echo "$start_line:$end_line"
}

# Check if control is currently enabled
is_control_enabled() {
    local policy_file="$1"
    local control_id="$2"
    local block_range
    
    block_range=$(find_control_block "$policy_file" "$control_id") || return 1
    
    local start_line end_line
    start_line=$(echo "$block_range" | cut -d: -f1)
    end_line=$(echo "$block_range" | cut -d: -f2)
    
    # Check if any non-comment lines exist in the control block
    local non_comment_lines
    non_comment_lines=$(sed -n "${start_line},${end_line}p" "$PROJECT_ROOT/$policy_file" | grep -v "^#" | grep -v "^[[:space:]]*$" | wc -l)
    
    [[ "$non_comment_lines" -gt 0 ]]
}

# Enable a control by uncommenting its block
enable_control() {
    local control_id="$1"
    local policy_file block_range start_line end_line
    
    log_verbose "Enabling control $control_id"
    
    policy_file=$(get_policy_file "$control_id") || return 1
    block_range=$(find_control_block "$policy_file" "$control_id") || return 1
    
    start_line=$(echo "$block_range" | cut -d: -f1)
    end_line=$(echo "$block_range" | cut -d: -f2)
    
    if is_control_enabled "$policy_file" "$control_id"; then
        log_warning "Control $control_id is already enabled"
        return 0
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would enable control $control_id in $policy_file (lines $start_line-$end_line)"
        return 0
    fi
    
    # Create backup
    cp "$PROJECT_ROOT/$policy_file" "$PROJECT_ROOT/$policy_file.bak"
    
    # Uncomment the control block (except for the control header comments)
    sed -i.tmp "${start_line},${end_line}s/^# \(package\|import\|deny\|has_\)/\1/" "$PROJECT_ROOT/$policy_file"
    sed -i.tmp "${start_line},${end_line}s/^#\([[:space:]]*[^[:space:]#]\)/\1/" "$PROJECT_ROOT/$policy_file"
    
    # Remove temporary file
    rm -f "$PROJECT_ROOT/$policy_file.tmp"
    
    log_success "Enabled control $control_id"
}

# Disable a control by commenting its block
disable_control() {
    local control_id="$1"
    local policy_file block_range start_line end_line
    
    log_verbose "Disabling control $control_id"
    
    policy_file=$(get_policy_file "$control_id") || return 1
    block_range=$(find_control_block "$policy_file" "$control_id") || return 1
    
    start_line=$(echo "$block_range" | cut -d: -f1)
    end_line=$(echo "$block_range" | cut -d: -f2)
    
    if ! is_control_enabled "$policy_file" "$control_id"; then
        log_warning "Control $control_id is already disabled"
        return 0
    fi
    
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "DRY RUN: Would disable control $control_id in $policy_file (lines $start_line-$end_line)"
        return 0
    fi
    
    # Create backup
    cp "$PROJECT_ROOT/$policy_file" "$PROJECT_ROOT/$policy_file.bak"
    
    # Comment out the control block (except for the control header comments)
    sed -i.tmp "${start_line},${end_line}s/^\(package\|import\|deny\|has_\)/# \1/" "$PROJECT_ROOT/$policy_file"
    sed -i.tmp "${start_line},${end_line}s/^\([[:space:]]*[^[:space:]#]\)/# \1/" "$PROJECT_ROOT/$policy_file"
    
    # Remove temporary file
    rm -f "$PROJECT_ROOT/$policy_file.tmp"
    
    log_success "Disabled control $control_id"
}

# Show control status
show_control_status() {
    local control_id="$1"
    local policy_file control_info
    
    control_info=$(get_control_info "$control_id") || return 1
    policy_file=$(echo "$control_info" | jq -r '.policy_file')
    
    local title severity cloud_provider domain
    title=$(echo "$control_info" | jq -r '.title')
    severity=$(echo "$control_info" | jq -r '.severity')
    cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
    domain=$(echo "$control_info" | jq -r '.domain')
    
    local status_color status_text
    if is_control_enabled "$policy_file" "$control_id"; then
        status_color="$GREEN"
        status_text="ENABLED"
    else
        status_color="$RED"
        status_text="DISABLED"
    fi
    
    echo -e "${BLUE}Control ID:${NC} $control_id"
    echo -e "${BLUE}Title:${NC} $title"
    echo -e "${BLUE}Status:${NC} ${status_color}$status_text${NC}"
    echo -e "${BLUE}Severity:${NC} $severity"
    echo -e "${BLUE}Cloud:${NC} $cloud_provider"
    echo -e "${BLUE}Domain:${NC} $domain"
    echo -e "${BLUE}Policy File:${NC} $policy_file"
}

# List all controls and their status
list_all_controls() {
    local controls enabled_count disabled_count total_count
    
    log_info "Scanning all controls..."
    
    controls=$(jq -r '.controls | keys[]' "$CONTROL_METADATA" | sort)
    enabled_count=0
    disabled_count=0
    total_count=0
    
    printf "%-12s %-8s %-10s %-8s %-60s\n" "CONTROL_ID" "STATUS" "SEVERITY" "CLOUD" "TITLE"
    printf "%-12s %-8s %-10s %-8s %-60s\n" "----------" "------" "--------" "-----" "-----"
    
    while IFS= read -r control_id; do
        local control_info policy_file title severity cloud_provider
        
        control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
        policy_file=$(echo "$control_info" | jq -r '.policy_file')
        title=$(echo "$control_info" | jq -r '.title')
        severity=$(echo "$control_info" | jq -r '.severity')
        cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
        
        local status_text status_color
        if is_control_enabled "$policy_file" "$control_id"; then
            status_text="ENABLED"
            status_color="$GREEN"
            ((enabled_count++))
        else
            status_text="DISABLED"
            status_color="$RED"
            ((disabled_count++))
        fi
        
        ((total_count++))
        
        # Truncate title if too long
        if [[ ${#title} -gt 58 ]]; then
            title="${title:0:55}..."
        fi
        
        printf "%-12s ${status_color}%-8s${NC} %-10s %-8s %-60s\n" \
            "$control_id" "$status_text" "$severity" "$cloud_provider" "$title"
    done <<< "$controls"
    
    echo
    log_info "Summary: $total_count total controls, ${GREEN}$enabled_count enabled${NC}, ${RED}$disabled_count disabled${NC}"
}

# Main function
main() {
    local command=""
    local control_id=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            enable|disable|status|list)
                command="$1"
                shift
                ;;
            *)
                if [[ -z "$control_id" && "$command" != "list" ]]; then
                    control_id="$1"
                else
                    log_error "Unknown argument: $1"
                    usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$command" ]]; then
        log_error "No command specified"
        usage
        exit 1
    fi
    
    if [[ "$command" != "list" && -z "$control_id" ]]; then
        log_error "Control ID required for command: $command"
        usage
        exit 1
    fi
    
    # Check dependencies and project structure
    check_dependencies
    validate_project_structure
    
    # Execute command
    case "$command" in
        enable)
            enable_control "$control_id"
            ;;
        disable)
            disable_control "$control_id"
            ;;
        status)
            show_control_status "$control_id"
            ;;
        list)
            list_all_controls
            ;;
        *)
            log_error "Unknown command: $command"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi