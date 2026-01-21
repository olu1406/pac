#!/bin/bash

# List Controls Script for Multi-Cloud Security Policy System
# Displays comprehensive information about all available security controls

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
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS] [FILTER]

List Controls Script - Display security control information

OPTIONS:
    -h, --help              Show this help message
    -v, --verbose           Show detailed control information
    -f, --format FORMAT     Output format: table, json, csv (default: table)
    -s, --status STATUS     Filter by status: enabled, disabled, all (default: all)
    -c, --cloud CLOUD       Filter by cloud provider: aws, azure, multi (default: all)
    -d, --domain DOMAIN     Filter by domain: identity, networking, logging, data, governance
    -S, --severity SEVERITY Filter by severity: critical, high, medium, low
    --framework FRAMEWORK   Filter by framework: nist, cis, iso
    --sort FIELD           Sort by field: id, title, severity, cloud, domain, status
    --no-color             Disable colored output

EXAMPLES:
    $0                                    # List all controls in table format
    $0 --status enabled                   # List only enabled controls
    $0 --cloud aws --domain identity      # List AWS identity controls
    $0 --severity critical --format json  # List critical controls in JSON
    $0 --framework nist --verbose         # List NIST controls with details
    $0 --sort severity                    # Sort controls by severity

FILTER:
    Optional text filter to search in control titles and descriptions

EOF
}

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
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

# Check if control is currently enabled
is_control_enabled() {
    local policy_file="$1"
    local control_id="$2"
    
    if [[ ! -f "$PROJECT_ROOT/$policy_file" ]]; then
        return 1
    fi
    
    # Find control block
    local start_line
    start_line=$(grep -n "^# CONTROL: $control_id$" "$PROJECT_ROOT/$policy_file" | cut -d: -f1)
    
    if [[ -z "$start_line" ]]; then
        return 1
    fi
    
    # Find end of control block
    local end_line
    end_line=$(tail -n +$((start_line + 1)) "$PROJECT_ROOT/$policy_file" | grep -n "^# CONTROL:" | head -1 | cut -d: -f1)
    
    if [[ -n "$end_line" ]]; then
        end_line=$((start_line + end_line - 1))
    else
        end_line=$(wc -l < "$PROJECT_ROOT/$policy_file")
    fi
    
    # Check if any non-comment lines exist in the control block
    local non_comment_lines
    non_comment_lines=$(sed -n "${start_line},${end_line}p" "$PROJECT_ROOT/$policy_file" | grep -v "^#" | grep -v "^[[:space:]]*$" | wc -l)
    
    [[ "$non_comment_lines" -gt 0 ]]
}

# Get severity color
get_severity_color() {
    local severity="$1"
    
    case "$severity" in
        CRITICAL) echo "$RED" ;;
        HIGH) echo "$MAGENTA" ;;
        MEDIUM) echo "$YELLOW" ;;
        LOW) echo "$CYAN" ;;
        *) echo "$NC" ;;
    esac
}

# Get status color
get_status_color() {
    local status="$1"
    
    case "$status" in
        ENABLED) echo "$GREEN" ;;
        DISABLED) echo "$RED" ;;
        *) echo "$NC" ;;
    esac
}

# Filter controls based on criteria
filter_controls() {
    local controls="$1"
    local status_filter="${STATUS_FILTER:-all}"
    local cloud_filter="${CLOUD_FILTER:-all}"
    local domain_filter="${DOMAIN_FILTER:-all}"
    local severity_filter="${SEVERITY_FILTER:-all}"
    local framework_filter="${FRAMEWORK_FILTER:-all}"
    local text_filter="${TEXT_FILTER:-}"
    
    local filtered_controls=""
    
    while IFS= read -r control_id; do
        local control_info policy_file title severity cloud_provider domain
        local frameworks_text status
        
        control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
        policy_file=$(echo "$control_info" | jq -r '.policy_file')
        title=$(echo "$control_info" | jq -r '.title')
        severity=$(echo "$control_info" | jq -r '.severity')
        cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
        domain=$(echo "$control_info" | jq -r '.domain')
        
        # Get frameworks as text
        frameworks_text=$(echo "$control_info" | jq -r '.frameworks | to_entries | map("\(.key):\(.value | join(","))") | join(" ")')
        
        # Determine status
        if is_control_enabled "$policy_file" "$control_id"; then
            status="ENABLED"
        else
            status="DISABLED"
        fi
        
        # Apply filters
        if [[ "$status_filter" != "all" && "$status" != "$(echo "$status_filter" | tr '[:lower:]' '[:upper:]')" ]]; then
            continue
        fi
        
        if [[ "$cloud_filter" != "all" && "$cloud_provider" != "$cloud_filter" ]]; then
            continue
        fi
        
        if [[ "$domain_filter" != "all" && "$domain" != "$domain_filter" ]]; then
            continue
        fi
        
        if [[ "$severity_filter" != "all" && "$severity" != "$(echo "$severity_filter" | tr '[:lower:]' '[:upper:]')" ]]; then
            continue
        fi
        
        if [[ "$framework_filter" != "all" && ! "$frameworks_text" =~ $framework_filter ]]; then
            continue
        fi
        
        if [[ -n "$text_filter" ]]; then
            local search_text="$control_id $title $(echo "$control_info" | jq -r '.description // ""')"
            if [[ ! "$search_text" =~ $text_filter ]]; then
                continue
            fi
        fi
        
        filtered_controls+="$control_id"$'\n'
    done <<< "$controls"
    
    echo -n "$filtered_controls"
}

# Sort controls
sort_controls() {
    local controls="$1"
    local sort_field="${SORT_FIELD:-id}"
    
    case "$sort_field" in
        id)
            echo "$controls" | sort
            ;;
        title)
            {
                while IFS= read -r control_id; do
                    local title
                    title=$(jq -r ".controls.\"$control_id\".title" "$CONTROL_METADATA")
                    echo "$title|$control_id"
                done <<< "$controls"
            } | sort | cut -d'|' -f2
            ;;
        severity)
            {
                while IFS= read -r control_id; do
                    local severity severity_num
                    severity=$(jq -r ".controls.\"$control_id\".severity" "$CONTROL_METADATA")
                    case "$severity" in
                        CRITICAL) severity_num=4 ;;
                        HIGH) severity_num=3 ;;
                        MEDIUM) severity_num=2 ;;
                        LOW) severity_num=1 ;;
                        *) severity_num=0 ;;
                    esac
                    echo "$severity_num|$control_id"
                done <<< "$controls"
            } | sort -nr | cut -d'|' -f2
            ;;
        cloud)
            {
                while IFS= read -r control_id; do
                    local cloud_provider
                    cloud_provider=$(jq -r ".controls.\"$control_id\".cloud_provider" "$CONTROL_METADATA")
                    echo "$cloud_provider|$control_id"
                done <<< "$controls"
            } | sort | cut -d'|' -f2
            ;;
        domain)
            {
                while IFS= read -r control_id; do
                    local domain
                    domain=$(jq -r ".controls.\"$control_id\".domain" "$CONTROL_METADATA")
                    echo "$domain|$control_id"
                done <<< "$controls"
            } | sort | cut -d'|' -f2
            ;;
        status)
            {
                while IFS= read -r control_id; do
                    local policy_file status
                    policy_file=$(jq -r ".controls.\"$control_id\".policy_file" "$CONTROL_METADATA")
                    if is_control_enabled "$policy_file" "$control_id"; then
                        status="ENABLED"
                    else
                        status="DISABLED"
                    fi
                    echo "$status|$control_id"
                done <<< "$controls"
            } | sort | cut -d'|' -f2
            ;;
        *)
            echo "$controls" | sort
            ;;
    esac
}

# Display controls in table format
display_table() {
    local controls="$1"
    local show_verbose="${VERBOSE:-false}"
    
    if [[ "$show_verbose" == "true" ]]; then
        # Verbose table format
        while IFS= read -r control_id; do
            [[ -z "$control_id" ]] && continue
            
            local control_info policy_file title severity cloud_provider domain description
            local frameworks status status_color severity_color
            
            control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
            policy_file=$(echo "$control_info" | jq -r '.policy_file')
            title=$(echo "$control_info" | jq -r '.title')
            severity=$(echo "$control_info" | jq -r '.severity')
            cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
            domain=$(echo "$control_info" | jq -r '.domain')
            description=$(echo "$control_info" | jq -r '.description // ""')
            
            # Get frameworks
            frameworks=$(echo "$control_info" | jq -r '.frameworks | to_entries | map("\(.key | ascii_upcase):\(.value | join(","))") | join(" ")')
            
            # Determine status
            if is_control_enabled "$policy_file" "$control_id"; then
                status="ENABLED"
            else
                status="DISABLED"
            fi
            
            status_color=$(get_status_color "$status")
            severity_color=$(get_severity_color "$severity")
            
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${BLUE}Control ID:${NC} $control_id"
            echo -e "${BLUE}Title:${NC} $title"
            echo -e "${BLUE}Status:${NC} ${status_color}$status${NC}"
            echo -e "${BLUE}Severity:${NC} ${severity_color}$severity${NC}"
            echo -e "${BLUE}Cloud:${NC} $cloud_provider"
            echo -e "${BLUE}Domain:${NC} $domain"
            echo -e "${BLUE}Frameworks:${NC} $frameworks"
            echo -e "${BLUE}Policy File:${NC} $policy_file"
            if [[ -n "$description" ]]; then
                echo -e "${BLUE}Description:${NC} $description"
            fi
            echo
        done <<< "$controls"
    else
        # Compact table format
        printf "%-12s %-8s %-10s %-8s %-12s %-60s\n" "CONTROL_ID" "STATUS" "SEVERITY" "CLOUD" "DOMAIN" "TITLE"
        printf "%-12s %-8s %-10s %-8s %-12s %-60s\n" "----------" "------" "--------" "-----" "------" "-----"
        
        while IFS= read -r control_id; do
            [[ -z "$control_id" ]] && continue
            
            local control_info policy_file title severity cloud_provider domain
            local status status_color severity_color
            
            control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
            policy_file=$(echo "$control_info" | jq -r '.policy_file')
            title=$(echo "$control_info" | jq -r '.title')
            severity=$(echo "$control_info" | jq -r '.severity')
            cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
            domain=$(echo "$control_info" | jq -r '.domain')
            
            # Determine status
            if is_control_enabled "$policy_file" "$control_id"; then
                status="ENABLED"
            else
                status="DISABLED"
            fi
            
            status_color=$(get_status_color "$status")
            severity_color=$(get_severity_color "$severity")
            
            # Truncate title if too long
            if [[ ${#title} -gt 58 ]]; then
                title="${title:0:55}..."
            fi
            
            printf "%-12s ${status_color}%-8s${NC} ${severity_color}%-10s${NC} %-8s %-12s %-60s\n" \
                "$control_id" "$status" "$severity" "$cloud_provider" "$domain" "$title"
        done <<< "$controls"
    fi
}

# Display controls in JSON format
display_json() {
    local controls="$1"
    local json_output="[]"
    
    while IFS= read -r control_id; do
        [[ -z "$control_id" ]] && continue
        
        local control_info policy_file status
        
        control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
        policy_file=$(echo "$control_info" | jq -r '.policy_file')
        
        # Determine status
        if is_control_enabled "$policy_file" "$control_id"; then
            status="enabled"
        else
            status="disabled"
        fi
        
        # Add status to control info
        local control_with_status
        control_with_status=$(echo "$control_info" | jq --arg status "$status" '. + {status: $status}')
        
        # Add to output array
        json_output=$(echo "$json_output" | jq --argjson control "$control_with_status" '. + [$control]')
    done <<< "$controls"
    
    echo "$json_output" | jq '.'
}

# Display controls in CSV format
display_csv() {
    local controls="$1"
    
    # CSV header
    echo "control_id,title,status,severity,cloud_provider,domain,policy_file,frameworks"
    
    while IFS= read -r control_id; do
        [[ -z "$control_id" ]] && continue
        
        local control_info policy_file title severity cloud_provider domain
        local frameworks status
        
        control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
        policy_file=$(echo "$control_info" | jq -r '.policy_file')
        title=$(echo "$control_info" | jq -r '.title')
        severity=$(echo "$control_info" | jq -r '.severity')
        cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
        domain=$(echo "$control_info" | jq -r '.domain')
        
        # Get frameworks as comma-separated string
        frameworks=$(echo "$control_info" | jq -r '.frameworks | to_entries | map("\(.key):\(.value | join(";"))") | join(",")')
        
        # Determine status
        if is_control_enabled "$policy_file" "$control_id"; then
            status="enabled"
        else
            status="disabled"
        fi
        
        # Escape quotes in title
        title=$(echo "$title" | sed 's/"/""/g')
        
        echo "\"$control_id\",\"$title\",\"$status\",\"$severity\",\"$cloud_provider\",\"$domain\",\"$policy_file\",\"$frameworks\""
    done <<< "$controls"
}

# Display summary statistics
display_summary() {
    local controls="$1"
    local total_count enabled_count disabled_count
    local aws_count azure_count critical_count high_count medium_count low_count
    
    total_count=0
    enabled_count=0
    disabled_count=0
    aws_count=0
    azure_count=0
    critical_count=0
    high_count=0
    medium_count=0
    low_count=0
    
    while IFS= read -r control_id; do
        [[ -z "$control_id" ]] && continue
        
        local control_info policy_file severity cloud_provider
        
        control_info=$(jq -r ".controls.\"$control_id\"" "$CONTROL_METADATA")
        policy_file=$(echo "$control_info" | jq -r '.policy_file')
        severity=$(echo "$control_info" | jq -r '.severity')
        cloud_provider=$(echo "$control_info" | jq -r '.cloud_provider')
        
        ((total_count++))
        
        # Count by status
        if is_control_enabled "$policy_file" "$control_id"; then
            ((enabled_count++))
        else
            ((disabled_count++))
        fi
        
        # Count by cloud provider
        case "$cloud_provider" in
            aws) ((aws_count++)) ;;
            azure) ((azure_count++)) ;;
        esac
        
        # Count by severity
        case "$severity" in
            CRITICAL) ((critical_count++)) ;;
            HIGH) ((high_count++)) ;;
            MEDIUM) ((medium_count++)) ;;
            LOW) ((low_count++)) ;;
        esac
    done <<< "$controls"
    
    echo
    log_info "Control Summary:"
    echo -e "  Total Controls: $total_count"
    echo -e "  ${GREEN}Enabled: $enabled_count${NC}"
    echo -e "  ${RED}Disabled: $disabled_count${NC}"
    echo
    echo -e "  Cloud Providers:"
    echo -e "    AWS: $aws_count"
    echo -e "    Azure: $azure_count"
    echo
    echo -e "  Severity Distribution:"
    echo -e "    ${RED}Critical: $critical_count${NC}"
    echo -e "    ${MAGENTA}High: $high_count${NC}"
    echo -e "    ${YELLOW}Medium: $medium_count${NC}"
    echo -e "    ${CYAN}Low: $low_count${NC}"
}

# Main function
main() {
    local format="table"
    
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
            -f|--format)
                format="$2"
                shift 2
                ;;
            -s|--status)
                STATUS_FILTER="$2"
                shift 2
                ;;
            -c|--cloud)
                CLOUD_FILTER="$2"
                shift 2
                ;;
            -d|--domain)
                DOMAIN_FILTER="$2"
                shift 2
                ;;
            -S|--severity)
                SEVERITY_FILTER="$2"
                shift 2
                ;;
            --framework)
                FRAMEWORK_FILTER="$2"
                shift 2
                ;;
            --sort)
                SORT_FIELD="$2"
                shift 2
                ;;
            --no-color)
                RED=""
                GREEN=""
                YELLOW=""
                BLUE=""
                CYAN=""
                MAGENTA=""
                NC=""
                shift
                ;;
            *)
                TEXT_FILTER="$1"
                shift
                ;;
        esac
    done
    
    # Validate format
    case "$format" in
        table|json|csv) ;;
        *)
            log_error "Invalid format: $format. Use table, json, or csv"
            exit 1
            ;;
    esac
    
    # Check dependencies and project structure
    check_dependencies
    validate_project_structure
    
    # Get all controls
    local all_controls
    all_controls=$(jq -r '.controls | keys[]' "$CONTROL_METADATA")
    
    # Filter controls
    local filtered_controls
    filtered_controls=$(filter_controls "$all_controls")
    
    if [[ -z "$filtered_controls" ]]; then
        log_info "No controls match the specified criteria"
        exit 0
    fi
    
    # Sort controls
    local sorted_controls
    sorted_controls=$(sort_controls "$filtered_controls")
    
    # Display controls
    case "$format" in
        table)
            display_table "$sorted_controls"
            if [[ "${VERBOSE:-false}" != "true" ]]; then
                display_summary "$sorted_controls"
            fi
            ;;
        json)
            display_json "$sorted_controls"
            ;;
        csv)
            display_csv "$sorted_controls"
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi