#!/bin/bash

# Compliance Export Script
# Exports compliance matrices and historical data in CSV/JSON formats

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="${POLICIES_DIR:-$PROJECT_ROOT/policies}"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/reports}"
METADATA_FILE="$POLICIES_DIR/control_metadata.json"

# Default configuration
OUTPUT_FORMAT="${OUTPUT_FORMAT:-both}"
OUTPUT_DIR="${OUTPUT_DIR:-$REPORTS_DIR}"
INCLUDE_HISTORICAL="${INCLUDE_HISTORICAL:-true}"
FRAMEWORK_FILTER="${FRAMEWORK_FILTER:-all}"
CLOUD_FILTER="${CLOUD_FILTER:-all}"
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

Export compliance matrices and historical data in CSV/JSON formats.

OPTIONS:
    -f, --format FORMAT         Output format: csv, json, both (default: both)
    -o, --output-dir DIR        Output directory (default: $REPORTS_DIR)
    -w, --framework FRAMEWORK   Filter by framework: nist, cis, iso, all (default: all)
    -c, --cloud PROVIDER        Filter by cloud: aws, azure, all (default: all)
    -h, --historical            Include historical compliance data (default: true)
    --no-historical             Exclude historical compliance data
    -v, --verbose               Enable verbose output
    --help                      Show this help message

EXAMPLES:
    $0                          # Export all compliance data in both formats
    $0 -f csv -w nist           # Export NIST mappings in CSV format
    $0 -c aws --no-historical   # Export AWS controls without historical data
    $0 -o /tmp/compliance       # Export to specific directory

ENVIRONMENT VARIABLES:
    OUTPUT_FORMAT               Override output format
    OUTPUT_DIR                  Override output directory
    FRAMEWORK_FILTER            Override framework filter
    CLOUD_FILTER                Override cloud provider filter
    INCLUDE_HISTORICAL          Include historical data (true/false)
    VERBOSE                     Enable verbose output (true/false)

EOF
}
# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -w|--framework)
                FRAMEWORK_FILTER="$2"
                shift 2
                ;;
            -c|--cloud)
                CLOUD_FILTER="$2"
                shift 2
                ;;
            -h|--historical)
                INCLUDE_HISTORICAL="true"
                shift
                ;;
            --no-historical)
                INCLUDE_HISTORICAL="false"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --help)
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

# Validate inputs
validate_inputs() {
    # Validate output format
    case "$OUTPUT_FORMAT" in
        csv|json|both)
            log_debug "Output format validated: $OUTPUT_FORMAT"
            ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            log_info "Supported formats: csv, json, both"
            exit 1
            ;;
    esac
    
    # Validate framework filter
    case "$FRAMEWORK_FILTER" in
        nist|cis|iso|all)
            log_debug "Framework filter validated: $FRAMEWORK_FILTER"
            ;;
        *)
            log_error "Invalid framework filter: $FRAMEWORK_FILTER"
            log_info "Supported frameworks: nist, cis, iso, all"
            exit 1
            ;;
    esac
    
    # Validate cloud filter
    case "$CLOUD_FILTER" in
        aws|azure|all)
            log_debug "Cloud filter validated: $CLOUD_FILTER"
            ;;
        *)
            log_error "Invalid cloud filter: $CLOUD_FILTER"
            log_info "Supported providers: aws, azure, all"
            exit 1
            ;;
    esac
    
    # Check metadata file
    if [[ ! -f "$METADATA_FILE" ]]; then
        log_error "Control metadata file not found: $METADATA_FILE"
        exit 1
    fi
    
    if ! jq empty "$METADATA_FILE" 2>/dev/null; then
        log_error "Control metadata file is not valid JSON: $METADATA_FILE"
        exit 1
    fi
}

# Load control metadata with filtering
load_filtered_metadata() {
    local metadata
    metadata=$(cat "$METADATA_FILE")
    
    # Apply cloud provider filter
    if [[ "$CLOUD_FILTER" != "all" ]]; then
        log_debug "Applying cloud provider filter: $CLOUD_FILTER"
        metadata=$(echo "$metadata" | jq --arg cloud "$CLOUD_FILTER" '
            .controls |= with_entries(select(.value.cloud_provider == $cloud)) |
            .metadata.total_controls = (.controls | length)
        ')
    fi
    
    # Apply framework filter
    if [[ "$FRAMEWORK_FILTER" != "all" ]]; then
        log_debug "Applying framework filter: $FRAMEWORK_FILTER"
        local framework_key
        case "$FRAMEWORK_FILTER" in
            nist) framework_key="nist_800_53" ;;
            cis) framework_key="cis_aws,cis_azure" ;;
            iso) framework_key="iso_27001" ;;
        esac
        
        metadata=$(echo "$metadata" | jq --arg fw "$framework_key" '
            .controls |= with_entries(
                select(
                    if $fw == "cis_aws,cis_azure" then
                        (.value.frameworks.cis_aws or .value.frameworks.cis_azure)
                    else
                        .value.frameworks[$fw]
                    end
                )
            ) |
            .metadata.total_controls = (.controls | length)
        ')
    fi
    
    echo "$metadata"
}

# Generate export metadata
generate_export_metadata() {
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local commit_hash
    commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    cat << EOF
{
    "timestamp": "$timestamp",
    "commit_hash": "$commit_hash",
    "format": "$OUTPUT_FORMAT",
    "framework_filter": "$FRAMEWORK_FILTER",
    "cloud_filter": "$CLOUD_FILTER",
    "include_historical": $INCLUDE_HISTORICAL,
    "source_file": "$METADATA_FILE"
}
EOF
}

# Collect historical compliance data
collect_historical_data() {
    local historical_data="[]"
    
    if [[ "$INCLUDE_HISTORICAL" != "true" ]]; then
        echo "$historical_data"
        return 0
    fi
    
    log_debug "Collecting historical compliance data"
    
    # Look for previous compliance reports in the reports directory
    if [[ -d "$REPORTS_DIR" ]]; then
        local report_files
        report_files=$(find "$REPORTS_DIR" -name "*compliance*" -name "*.json" -type f 2>/dev/null | head -10 | sort -r)
        
        if [[ -n "$report_files" ]]; then
            log_debug "Found $(echo "$report_files" | wc -l) historical compliance files"
            
            # Extract metadata from historical reports
            historical_data=$(echo "$report_files" | while read -r file; do
                if [[ -f "$file" ]] && jq -e '.export_metadata' "$file" >/dev/null 2>&1; then
                    jq -c '.export_metadata + {"file": "'$(basename "$file")'"}' "$file" 2>/dev/null || true
                fi
            done | jq -s '.')
        fi
    fi
    
    echo "$historical_data"
}

# Generate framework mapping aggregation
generate_framework_aggregation() {
    local metadata="$1"
    
    log_debug "Generating framework mapping aggregation"
    
    echo "$metadata" | jq '
        .controls as $controls |
        {
            "framework_summary": {
                "nist_800_53": {
                    "total_controls": [$controls[] | select(.frameworks.nist_800_53)] | length,
                    "controls_by_severity": (
                        [$controls[] | select(.frameworks.nist_800_53)] |
                        group_by(.severity) |
                        map({
                            "severity": .[0].severity,
                            "count": length
                        })
                    ),
                    "controls_by_domain": (
                        [$controls[] | select(.frameworks.nist_800_53)] |
                        group_by(.domain) |
                        map({
                            "domain": .[0].domain,
                            "count": length
                        })
                    ),
                    "unique_nist_controls": (
                        [$controls[] | select(.frameworks.nist_800_53) | .frameworks.nist_800_53[]] |
                        unique | length
                    )
                },
                "cis": {
                    "total_controls": [$controls[] | select(.frameworks.cis_aws or .frameworks.cis_azure)] | length,
                    "aws_controls": [$controls[] | select(.frameworks.cis_aws)] | length,
                    "azure_controls": [$controls[] | select(.frameworks.cis_azure)] | length,
                    "controls_by_severity": (
                        [$controls[] | select(.frameworks.cis_aws or .frameworks.cis_azure)] |
                        group_by(.severity) |
                        map({
                            "severity": .[0].severity,
                            "count": length
                        })
                    )
                },
                "iso_27001": {
                    "total_controls": [$controls[] | select(.frameworks.iso_27001)] | length,
                    "controls_by_severity": (
                        [$controls[] | select(.frameworks.iso_27001)] |
                        group_by(.severity) |
                        map({
                            "severity": .[0].severity,
                            "count": length
                        })
                    ),
                    "unique_iso_controls": (
                        [$controls[] | select(.frameworks.iso_27001) | .frameworks.iso_27001[]] |
                        unique | length
                    )
                }
            },
            "cross_framework_mapping": [
                $controls | to_entries[] |
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "domain": .value.domain,
                    "frameworks": .value.frameworks,
                    "framework_count": (.value.frameworks | keys | length)
                }
            ] | sort_by(-.framework_count)
        }
    '
}

# Export JSON format
export_json() {
    local metadata="$1"
    local export_metadata="$2"
    local historical_data="$3"
    local framework_aggregation="$4"
    local output_file="$5"
    
    log_info "Generating JSON compliance export: $output_file"
    
    jq -n \
        --argjson export_meta "$export_metadata" \
        --argjson metadata "$metadata" \
        --argjson historical "$historical_data" \
        --argjson aggregation "$framework_aggregation" \
        '{
            "export_metadata": $export_meta,
            "control_metadata": $metadata.metadata,
            "framework_aggregation": $aggregation,
            "controls": $metadata.controls,
            "historical_data": $historical
        }' > "$output_file"
    
    log_success "JSON export completed: $output_file"
}

# Export CSV format
export_csv() {
    local metadata="$1"
    local output_file="$2"
    
    log_info "Generating CSV compliance export: $output_file"
    
    # Create CSV header
    cat > "$output_file" << EOF
Control_ID,Title,Severity,Cloud_Provider,Domain,NIST_800_53,CIS_AWS,CIS_Azure,ISO_27001,Policy_File,Description,Remediation,Framework_Count
EOF
    
    # Extract control data and convert to CSV
    echo "$metadata" | jq -r '
        .controls | to_entries[] |
        [
            .key,
            .value.title,
            .value.severity,
            .value.cloud_provider,
            .value.domain,
            (.value.frameworks.nist_800_53 // [] | join(";")),
            (.value.frameworks.cis_aws // [] | join(";")),
            (.value.frameworks.cis_azure // [] | join(";")),
            (.value.frameworks.iso_27001 // [] | join(";")),
            (.value.policy_file // ""),
            (.value.description // ""),
            (.value.remediation // ""),
            (.value.frameworks | keys | length)
        ] | @csv
    ' >> "$output_file"
    
    log_success "CSV export completed: $output_file"
}

# Generate output file paths
generate_output_paths() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    local base_name="compliance_export"
    
    if [[ "$FRAMEWORK_FILTER" != "all" ]]; then
        base_name="${base_name}_${FRAMEWORK_FILTER}"
    fi
    
    if [[ "$CLOUD_FILTER" != "all" ]]; then
        base_name="${base_name}_${CLOUD_FILTER}"
    fi
    
    JSON_OUTPUT_FILE="$OUTPUT_DIR/${base_name}_${timestamp}.json"
    CSV_OUTPUT_FILE="$OUTPUT_DIR/${base_name}_${timestamp}.csv"
    
    log_debug "Generated output paths:"
    log_debug "  JSON: $JSON_OUTPUT_FILE"
    log_debug "  CSV: $CSV_OUTPUT_FILE"
}

# Display summary statistics
display_summary() {
    local metadata="$1"
    local framework_aggregation="$2"
    
    log_info "=== Compliance Export Summary ==="
    
    local total_controls
    total_controls=$(echo "$metadata" | jq -r '.metadata.total_controls // 0')
    log_info "Total Controls: $total_controls"
    
    if [[ "$CLOUD_FILTER" == "all" ]]; then
        local aws_controls azure_controls
        aws_controls=$(echo "$metadata" | jq '[.controls[] | select(.cloud_provider == "aws")] | length')
        azure_controls=$(echo "$metadata" | jq '[.controls[] | select(.cloud_provider == "azure")] | length')
        log_info "AWS Controls: $aws_controls"
        log_info "Azure Controls: $azure_controls"
    fi
    
    log_info ""
    log_info "Controls by Severity:"
    echo "$metadata" | jq -r '.controls | to_entries | group_by(.value.severity) | .[] | "  \(.[0].value.severity): \(length) controls"' | sort -k2 -nr
    
    log_info ""
    log_info "Controls by Domain:"
    echo "$metadata" | jq -r '.controls | to_entries | group_by(.value.domain) | .[] | "  \(.[0].value.domain): \(length) controls"' | sort -k2 -nr
    
    log_info ""
    log_info "Framework Coverage:"
    echo "$framework_aggregation" | jq -r '
        .framework_summary |
        "  NIST 800-53: \(.nist_800_53.total_controls) controls",
        "  CIS Benchmarks: \(.cis.total_controls) controls",
        "  ISO 27001: \(.iso_27001.total_controls) controls"
    '
    
    if [[ "$INCLUDE_HISTORICAL" == "true" ]]; then
        log_info ""
        log_info "Historical Data: Included in export"
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting compliance export"
    log_info "Output Directory: $OUTPUT_DIR"
    log_info "Output Format: $OUTPUT_FORMAT"
    log_info "Framework Filter: $FRAMEWORK_FILTER"
    log_info "Cloud Filter: $CLOUD_FILTER"
    
    # Validate inputs and dependencies
    check_dependencies
    validate_inputs
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Generate output file paths
    generate_output_paths
    
    # Load and process data
    log_info "Loading control metadata..."
    local metadata
    metadata=$(load_filtered_metadata)
    
    log_info "Generating export metadata..."
    local export_metadata
    export_metadata=$(generate_export_metadata)
    
    log_info "Collecting historical data..."
    local historical_data
    historical_data=$(collect_historical_data)
    
    log_info "Generating framework aggregation..."
    local framework_aggregation
    framework_aggregation=$(generate_framework_aggregation "$metadata")
    
    # Export based on format
    case "$OUTPUT_FORMAT" in
        json)
            export_json "$metadata" "$export_metadata" "$historical_data" "$framework_aggregation" "$JSON_OUTPUT_FILE"
            echo "$JSON_OUTPUT_FILE"
            ;;
        csv)
            export_csv "$metadata" "$CSV_OUTPUT_FILE"
            echo "$CSV_OUTPUT_FILE"
            ;;
        both)
            export_json "$metadata" "$export_metadata" "$historical_data" "$framework_aggregation" "$JSON_OUTPUT_FILE"
            export_csv "$metadata" "$CSV_OUTPUT_FILE"
            echo "$JSON_OUTPUT_FILE"
            echo "$CSV_OUTPUT_FILE"
            ;;
    esac
    
    # Display summary
    display_summary "$metadata" "$framework_aggregation"
    
    log_success "Compliance export completed successfully!"
}

# Run main function
main "$@"