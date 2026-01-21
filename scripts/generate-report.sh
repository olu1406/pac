#!/bin/bash

# Report Generation Script
# Generates JSON and Markdown reports from policy violation data

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="${POLICIES_DIR:-$PROJECT_ROOT/policies}"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/reports}"

# Default configuration
INPUT_FILE="${INPUT_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPORTS_DIR}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-both}"
SEVERITY_FILTER="${SEVERITY_FILTER:-all}"
ENVIRONMENT="${ENVIRONMENT:-local}"
INCLUDE_METADATA="${INCLUDE_METADATA:-true}"
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

Generate JSON and Markdown reports from policy violation data.

OPTIONS:
    -i, --input FILE            Input violations JSON file (required)
    -o, --output-dir DIR        Output directory for reports (default: $REPORTS_DIR)
    -f, --format FORMAT         Output format: json, markdown, both (default: both)
    -s, --severity LEVEL        Filter by severity: low, medium, high, critical, all (default: all)
    -e, --environment ENV       Environment name for reporting (default: local)
    -m, --metadata              Include metadata in reports (default: true)
    --no-metadata               Exclude metadata from reports
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0 -i violations.json                           # Generate both JSON and Markdown reports
    $0 -i violations.json -f json                   # Generate only JSON report
    $0 -i violations.json -s high -e production     # Filter high severity in production
    $0 -i violations.json -o /tmp/reports           # Output to specific directory

ENVIRONMENT VARIABLES:
    INPUT_FILE                  Override input file
    OUTPUT_DIR                  Override output directory
    OUTPUT_FORMAT               Override output format
    SEVERITY_FILTER             Override severity filter
    ENVIRONMENT                 Override environment name
    INCLUDE_METADATA            Include metadata (true/false)
    VERBOSE                     Enable verbose output (true/false)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -s|--severity)
                SEVERITY_FILTER="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -m|--metadata)
                INCLUDE_METADATA="true"
                shift
                ;;
            --no-metadata)
                INCLUDE_METADATA="false"
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
    if ! command -v jq &> /dev/null; then
        log_error "jq command not found. Please install jq for JSON processing."
        exit 1
    fi
    
    log_debug "Dependencies validated successfully"
}

# Validate input file
validate_input_file() {
    if [[ -z "$INPUT_FILE" ]]; then
        log_error "Input file is required. Use -i option or set INPUT_FILE environment variable."
        exit 1
    fi
    
    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file does not exist: $INPUT_FILE"
        exit 1
    fi
    
    # Validate JSON format
    if ! jq empty "$INPUT_FILE" 2>/dev/null; then
        log_error "Input file is not valid JSON: $INPUT_FILE"
        exit 1
    fi
    
    log_debug "Input file validated: $INPUT_FILE"
}

# Validate output format
validate_output_format() {
    case "$OUTPUT_FORMAT" in
        json|markdown|both)
            log_debug "Output format validated: $OUTPUT_FORMAT"
            ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            log_info "Supported formats: json, markdown, both"
            exit 1
            ;;
    esac
}

# Validate severity filter
validate_severity_filter() {
    case "$SEVERITY_FILTER" in
        low|medium|high|critical|all)
            log_debug "Severity filter validated: $SEVERITY_FILTER"
            ;;
        *)
            log_error "Invalid severity filter: $SEVERITY_FILTER"
            log_info "Supported filters: low, medium, high, critical, all"
            exit 1
            ;;
    esac
}

# Load control metadata
load_control_metadata() {
    local metadata_file="$POLICIES_DIR/control_metadata.json"
    
    if [[ ! -f "$metadata_file" ]]; then
        log_warn "Control metadata file not found: $metadata_file"
        echo "{}"
        return 0
    fi
    
    if ! jq empty "$metadata_file" 2>/dev/null; then
        log_warn "Control metadata file is not valid JSON: $metadata_file"
        echo "{}"
        return 0
    fi
    
    cat "$metadata_file"
}

# Apply severity filtering
apply_severity_filter() {
    local violations_json="$1"
    
    if [[ "$SEVERITY_FILTER" == "all" ]]; then
        echo "$violations_json"
        return 0
    fi
    
    log_info "Applying severity filter: $SEVERITY_FILTER"
    
    # Define severity hierarchy for filtering
    local filter_query
    case "$SEVERITY_FILTER" in
        low)
            filter_query='.[] | select(.severity == "LOW" or .severity == "MEDIUM" or .severity == "HIGH" or .severity == "CRITICAL")'
            ;;
        medium)
            filter_query='.[] | select(.severity == "MEDIUM" or .severity == "HIGH" or .severity == "CRITICAL")'
            ;;
        high)
            filter_query='.[] | select(.severity == "HIGH" or .severity == "CRITICAL")'
            ;;
        critical)
            filter_query='.[] | select(.severity == "CRITICAL")'
            ;;
    esac
    
    # Apply filter and reconstruct array
    echo "$violations_json" | jq "[$filter_query]"
}

# Enrich violations with metadata
enrich_violations() {
    local violations_json="$1"
    local control_metadata="$2"
    
    log_debug "Enriching violations with control metadata"
    
    # Enrich each violation with additional metadata from control catalog
    echo "$violations_json" | jq --argjson metadata "$control_metadata" '
        map(
            . as $violation |
            ($metadata.controls // {})[$violation.control_id] as $control_info |
            if $control_info then
                . + {
                    "frameworks": ($control_info.frameworks // {}),
                    "domain": ($control_info.domain // "unknown"),
                    "cloud_provider": ($control_info.cloud_provider // "unknown"),
                    "description": ($control_info.description // ""),
                    "policy_file": ($control_info.policy_file // "")
                }
            else
                .
            end
        )
    '
}

# Generate violation summary statistics
generate_summary() {
    local violations_json="$1"
    
    log_debug "Generating violation summary statistics"
    
    echo "$violations_json" | jq '{
        "total_violations": length,
        "violations_by_severity": {
            "critical": [.[] | select(.severity == "CRITICAL")] | length,
            "high": [.[] | select(.severity == "HIGH")] | length,
            "medium": [.[] | select(.severity == "MEDIUM")] | length,
            "low": [.[] | select(.severity == "LOW")] | length
        },
        "violations_by_domain": (
            group_by(.domain // "unknown") |
            map({
                "domain": (.[0].domain // "unknown"),
                "count": length
            })
        ),
        "violations_by_cloud": (
            group_by(.cloud_provider // "unknown") |
            map({
                "cloud_provider": (.[0].cloud_provider // "unknown"),
                "count": length
            })
        )
    }'
}

# Generate scan metadata
generate_scan_metadata() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local commit_hash
    commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    local terraform_version
    terraform_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo "unknown")
    
    local conftest_version
    conftest_version=$(conftest --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
    
    local scan_mode="local"
    if [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]; then
        scan_mode="ci"
    fi
    
    cat << EOF
{
    "timestamp": "$timestamp",
    "environment": "$ENVIRONMENT",
    "commit_hash": "$commit_hash",
    "scan_mode": "$scan_mode",
    "terraform_version": "$terraform_version",
    "conftest_version": "$conftest_version",
    "severity_filter": "$SEVERITY_FILTER",
    "input_file": "$INPUT_FILE"
}
EOF
}

# Generate JSON report
generate_json_report() {
    local violations_json="$1"
    local summary_json="$2"
    local metadata_json="$3"
    local output_file="$4"
    
    log_info "Generating JSON report: $output_file"
    
    local report_json
    if [[ "$INCLUDE_METADATA" == "true" ]]; then
        report_json=$(jq -n \
            --argjson metadata "$metadata_json" \
            --argjson summary "$summary_json" \
            --argjson violations "$violations_json" \
            '{
                "scan_metadata": $metadata,
                "summary": $summary,
                "violations": $violations
            }')
    else
        report_json=$(jq -n \
            --argjson summary "$summary_json" \
            --argjson violations "$violations_json" \
            '{
                "summary": $summary,
                "violations": $violations
            }')
    fi
    
    echo "$report_json" | jq '.' > "$output_file"
    log_success "JSON report generated: $output_file"
}

# Generate Markdown report
generate_markdown_report() {
    local violations_json="$1"
    local summary_json="$2"
    local metadata_json="$3"
    local output_file="$4"
    
    log_info "Generating Markdown report: $output_file"
    
    local timestamp environment commit_hash
    timestamp=$(echo "$metadata_json" | jq -r '.timestamp')
    environment=$(echo "$metadata_json" | jq -r '.environment')
    commit_hash=$(echo "$metadata_json" | jq -r '.commit_hash')
    
    local total_violations critical_count high_count medium_count low_count
    total_violations=$(echo "$summary_json" | jq -r '.total_violations')
    critical_count=$(echo "$summary_json" | jq -r '.violations_by_severity.critical')
    high_count=$(echo "$summary_json" | jq -r '.violations_by_severity.high')
    medium_count=$(echo "$summary_json" | jq -r '.violations_by_severity.medium')
    low_count=$(echo "$summary_json" | jq -r '.violations_by_severity.low')
    
    cat > "$output_file" << EOF
# Security Policy Scan Report

EOF
    
    if [[ "$INCLUDE_METADATA" == "true" ]]; then
        cat >> "$output_file" << EOF
**Scan Date:** $timestamp  
**Environment:** $environment  
**Commit:** $commit_hash  

EOF
    fi
    
    cat >> "$output_file" << EOF
## Executive Summary

EOF
    
    if [[ "$total_violations" -eq 0 ]]; then
        cat >> "$output_file" << EOF
✅ **No policy violations found**

All security controls passed validation. Your infrastructure configuration meets the required security standards.

EOF
    else
        cat >> "$output_file" << EOF
⚠️ **$total_violations policy violation(s) detected**

| Severity | Count |
|----------|-------|
| 🔴 Critical | $critical_count |
| 🟠 High | $high_count |
| 🟡 Medium | $medium_count |
| 🔵 Low | $low_count |

EOF
    fi
    
    # Add domain breakdown if violations exist
    if [[ "$total_violations" -gt 0 ]]; then
        cat >> "$output_file" << EOF
### Violations by Domain

EOF
        echo "$summary_json" | jq -r '.violations_by_domain[] | "- **\(.domain | ascii_upcase)**: \(.count) violation(s)"' >> "$output_file"
        
        cat >> "$output_file" << EOF

### Violations by Cloud Provider

EOF
        echo "$summary_json" | jq -r '.violations_by_cloud[] | "- **\(.cloud_provider | ascii_upcase)**: \(.count) violation(s)"' >> "$output_file"
        
        cat >> "$output_file" << EOF

## Detailed Violations

EOF
        
        # Group violations by severity for better organization
        for severity in "CRITICAL" "HIGH" "MEDIUM" "LOW"; do
            local severity_violations
            severity_violations=$(echo "$violations_json" | jq --arg sev "$severity" '[.[] | select(.severity == $sev)]')
            local severity_count
            severity_count=$(echo "$severity_violations" | jq 'length')
            
            if [[ "$severity_count" -gt 0 ]]; then
                local severity_icon
                case "$severity" in
                    "CRITICAL") severity_icon="🔴" ;;
                    "HIGH") severity_icon="🟠" ;;
                    "MEDIUM") severity_icon="🟡" ;;
                    "LOW") severity_icon="🔵" ;;
                esac
                
                cat >> "$output_file" << EOF
### $severity_icon $severity Severity ($severity_count violations)

EOF
                
                echo "$severity_violations" | jq -r '.[] | 
                    "#### " + .control_id + ": " + (.message // "Policy violation") + "\n\n" +
                    "**Resource:** `" + (.resource_address // "unknown") + "`  \n" +
                    "**Resource Type:** `" + (.resource_type // "unknown") + "`  \n" +
                    (if .domain then "**Domain:** " + .domain + "  \n" else "" end) +
                    (if .cloud_provider then "**Cloud Provider:** " + .cloud_provider + "  \n" else "" end) +
                    (if .file_location then "**File:** " + .file_location.filename + ":" + (.file_location.line_number | tostring) + "  \n" else "" end) +
                    "\n**Remediation:**  \n" + (.remediation // "No remediation guidance available") + "\n\n" +
                    (if .description then "**Description:**  \n" + .description + "\n\n" else "" end) +
                    "---\n"
                ' >> "$output_file"
            fi
        done
    fi
    
    cat >> "$output_file" << EOF

## Framework Compliance

EOF
    
    if [[ "$total_violations" -eq 0 ]]; then
        cat >> "$output_file" << EOF
All framework requirements are currently met.

EOF
    else
        # Generate framework compliance summary
        echo "$violations_json" | jq -r '
            [.[] | .frameworks // {} | to_entries[]] |
            group_by(.key) |
            map({
                "framework": .[0].key,
                "violations": length,
                "controls": [.[].value[]] | flatten | unique
            }) |
            sort_by(.framework) |
            .[] |
            "### " + (.framework | ascii_upcase) + "\n\n" +
            "- **Violations:** " + (.violations | tostring) + "\n" +
            "- **Affected Controls:** " + (.controls | join(", ")) + "\n"
        ' >> "$output_file"
    fi
    
    cat >> "$output_file" << EOF

---

*Generated by Multi-Cloud Security Policy Scanner*  
*Report generated at: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
    
    log_success "Markdown report generated: $output_file"
}

# Generate output file paths
generate_output_paths() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    local base_name="security-report"
    if [[ "$ENVIRONMENT" != "local" ]]; then
        base_name="${base_name}_${ENVIRONMENT}"
    fi
    
    if [[ "$SEVERITY_FILTER" != "all" ]]; then
        base_name="${base_name}_${SEVERITY_FILTER}"
    fi
    
    JSON_OUTPUT_FILE="$OUTPUT_DIR/${base_name}_${timestamp}.json"
    MARKDOWN_OUTPUT_FILE="$OUTPUT_DIR/${base_name}_${timestamp}.md"
    
    log_debug "Generated output paths:"
    log_debug "  JSON: $JSON_OUTPUT_FILE"
    log_debug "  Markdown: $MARKDOWN_OUTPUT_FILE"
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting report generation"
    log_info "Input File: $INPUT_FILE"
    log_info "Output Directory: $OUTPUT_DIR"
    log_info "Output Format: $OUTPUT_FORMAT"
    log_info "Environment: $ENVIRONMENT"
    
    if [[ "$SEVERITY_FILTER" != "all" ]]; then
        log_info "Severity Filter: $SEVERITY_FILTER"
    fi
    
    # Validate inputs and dependencies
    check_dependencies
    validate_input_file
    validate_output_format
    validate_severity_filter
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Generate output file paths
    generate_output_paths
    
    # Load and process data
    log_info "Loading violation data..."
    local raw_violations
    raw_violations=$(cat "$INPUT_FILE")
    
    # Handle different input formats (array vs object with violations key)
    local violations_json
    if echo "$raw_violations" | jq -e '.violations' >/dev/null 2>&1; then
        violations_json=$(echo "$raw_violations" | jq '.violations')
    else
        violations_json="$raw_violations"
    fi
    
    # Apply severity filtering
    violations_json=$(apply_severity_filter "$violations_json")
    
    # Load control metadata and enrich violations
    log_info "Loading control metadata..."
    local control_metadata
    control_metadata=$(load_control_metadata)
    
    violations_json=$(enrich_violations "$violations_json" "$control_metadata")
    
    # Generate summary and metadata
    log_info "Generating summary statistics..."
    local summary_json
    summary_json=$(generate_summary "$violations_json")
    
    local metadata_json
    metadata_json=$(generate_scan_metadata)
    
    # Generate reports based on format
    case "$OUTPUT_FORMAT" in
        json)
            generate_json_report "$violations_json" "$summary_json" "$metadata_json" "$JSON_OUTPUT_FILE"
            echo "$JSON_OUTPUT_FILE"
            ;;
        markdown)
            generate_markdown_report "$violations_json" "$summary_json" "$metadata_json" "$MARKDOWN_OUTPUT_FILE"
            echo "$MARKDOWN_OUTPUT_FILE"
            ;;
        both)
            generate_json_report "$violations_json" "$summary_json" "$metadata_json" "$JSON_OUTPUT_FILE"
            generate_markdown_report "$violations_json" "$summary_json" "$metadata_json" "$MARKDOWN_OUTPUT_FILE"
            echo "$JSON_OUTPUT_FILE"
            echo "$MARKDOWN_OUTPUT_FILE"
            ;;
    esac
    
    # Display summary
    local total_violations
    total_violations=$(echo "$summary_json" | jq -r '.total_violations')
    
    if [[ "$total_violations" -eq 0 ]]; then
        log_success "Report generation completed - no violations found"
    else
        log_warn "Report generation completed - $total_violations violation(s) found"
    fi
    
    log_success "Reports saved to: $OUTPUT_DIR"
}

# Run main function
main "$@"