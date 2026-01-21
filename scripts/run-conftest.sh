#!/bin/bash

# Conftest Integration Script
# Executes OPA policies via Conftest against Terraform plan JSON files

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="${POLICIES_DIR:-$PROJECT_ROOT/policies}"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/reports}"

# Default configuration
INPUT_FILE="${INPUT_FILE:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
POLICY_DIRS="${POLICY_DIRS:-}"
SEVERITY_FILTER="${SEVERITY_FILTER:-all}"
FAIL_ON_WARN="${FAIL_ON_WARN:-false}"
VERBOSE="${VERBOSE:-false}"
COMBINE_RESULTS="${COMBINE_RESULTS:-true}"

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

Execute OPA policies via Conftest against Terraform plan JSON files.

OPTIONS:
    -i, --input FILE            Input Terraform plan JSON file (required)
    -o, --output FILE           Output file for results (default: auto-generated)
    -f, --format FORMAT         Output format: json, table, tap, junit (default: json)
    -p, --policy-dirs DIRS      Comma-separated policy directories (default: auto-discover)
    -s, --severity LEVEL        Filter by severity: low, medium, high, critical, all (default: all)
    -w, --fail-on-warn          Fail on warnings (default: false)
    -c, --combine               Combine results from multiple policy directories (default: true)
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0 -i plan.json                                    # Run all policies against plan.json
    $0 -i plan.json -f table                           # Output in table format
    $0 -i plan.json -p policies/aws,policies/common    # Use specific policy directories
    $0 -i plan.json -s high -w                         # Filter high severity and fail on warnings
    $0 -i plan.json -o results.json                    # Save results to specific file

ENVIRONMENT VARIABLES:
    INPUT_FILE                  Override input file
    OUTPUT_FILE                 Override output file
    OUTPUT_FORMAT               Override output format
    POLICY_DIRS                 Override policy directories
    SEVERITY_FILTER             Override severity filter
    FAIL_ON_WARN                Fail on warnings (true/false)
    VERBOSE                     Enable verbose output (true/false)
    POLICIES_DIR                Override base policies directory
    REPORTS_DIR                 Override reports directory

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
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -p|--policy-dirs)
                POLICY_DIRS="$2"
                shift 2
                ;;
            -s|--severity)
                SEVERITY_FILTER="$2"
                shift 2
                ;;
            -w|--fail-on-warn)
                FAIL_ON_WARN="true"
                shift
                ;;
            -c|--combine)
                COMBINE_RESULTS="true"
                shift
                ;;
            --no-combine)
                COMBINE_RESULTS="false"
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
    if ! command -v conftest &> /dev/null; then
        log_error "conftest command not found. Please install Conftest."
        log_info "Installation: https://www.conftest.dev/install/"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq command not found. Please install jq for JSON processing."
        exit 1
    fi
    
    log_debug "Dependencies validated successfully"
}

# Get conftest version
get_conftest_version() {
    conftest --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown"
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

# Discover policy directories
discover_policy_directories() {
    local discovered_dirs=()
    
    if [[ -n "$POLICY_DIRS" ]]; then
        # Use specified directories
        IFS=',' read -ra dirs <<< "$POLICY_DIRS"
        for dir in "${dirs[@]}"; do
            dir=$(echo "$dir" | xargs)  # Trim whitespace
            if [[ -d "$dir" ]]; then
                discovered_dirs+=("$dir")
            else
                log_warn "Policy directory not found: $dir"
            fi
        done
    else
        # Auto-discover policy directories, excluding optional and template files
        if [[ -d "$POLICIES_DIR" ]]; then
            # Find subdirectories with .rego files, excluding optional directory
            while IFS= read -r -d '' dir; do
                # Skip optional directory
                if [[ "$dir" == *"/optional" ]]; then
                    continue
                fi
                # Skip directories with only template files
                if find "$dir" -name "*.rego" -type f -exec grep -l "^package\|^deny\|^violation" {} \; | grep -q .; then
                    discovered_dirs+=("$dir")
                fi
            done < <(find "$POLICIES_DIR" -type f -name "*.rego" -not -path "*/optional/*" -exec dirname {} \; | sort -u | tr '\n' '\0')
            
            # If no subdirectories with .rego files, use the base directory
            if [[ ${#discovered_dirs[@]} -eq 0 ]] && find "$POLICIES_DIR" -maxdepth 1 -name "*.rego" -type f | grep -q .; then
                discovered_dirs+=("$POLICIES_DIR")
            fi
        fi
    fi
    
    if [[ ${#discovered_dirs[@]} -eq 0 ]]; then
        log_error "No policy directories found"
        log_info "Searched in: $POLICIES_DIR"
        if [[ -n "$POLICY_DIRS" ]]; then
            log_info "Specified directories: $POLICY_DIRS"
        fi
        exit 1
    fi
    
    log_info "Found ${#discovered_dirs[@]} policy directories:"
    for dir in "${discovered_dirs[@]}"; do
        local rego_count
        rego_count=$(find "$dir" -name "*.rego" -type f | wc -l)
        log_info "  - $dir ($rego_count policies)"
    done
    
    printf '%s\n' "${discovered_dirs[@]}"
}

# Validate output format
validate_output_format() {
    case "$OUTPUT_FORMAT" in
        json|table|tap|junit)
            log_debug "Output format validated: $OUTPUT_FORMAT"
            ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            log_info "Supported formats: json, table, tap, junit"
            exit 1
            ;;
    esac
}

# Generate output file path
generate_output_file() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        return 0
    fi
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Generate file name based on input file and format
    local input_basename
    input_basename=$(basename "$INPUT_FILE" .json)
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    case "$OUTPUT_FORMAT" in
        json)
            OUTPUT_FILE="$REPORTS_DIR/conftest_${input_basename}_${timestamp}.json"
            ;;
        table)
            OUTPUT_FILE="$REPORTS_DIR/conftest_${input_basename}_${timestamp}.txt"
            ;;
        tap)
            OUTPUT_FILE="$REPORTS_DIR/conftest_${input_basename}_${timestamp}.tap"
            ;;
        junit)
            OUTPUT_FILE="$REPORTS_DIR/conftest_${input_basename}_${timestamp}.xml"
            ;;
    esac
    
    log_debug "Generated output file: $OUTPUT_FILE"
}

# Run conftest on single policy directory
run_conftest_single() {
    local policy_dir="$1"
    local temp_output="$2"
    
    log_info "Running Conftest against policy directory: $policy_dir"
    
    # Count policies in directory
    local policy_count
    policy_count=$(find "$policy_dir" -name "*.rego" -type f | wc -l)
    log_debug "Found $policy_count policy files in $policy_dir"
    
    # Prepare conftest command
    local conftest_cmd="conftest test --policy $policy_dir"
    
    # Add output format
    case "$OUTPUT_FORMAT" in
        json)
            conftest_cmd="$conftest_cmd --output json"
            ;;
        table)
            conftest_cmd="$conftest_cmd --output table"
            ;;
        tap)
            conftest_cmd="$conftest_cmd --output tap"
            ;;
        junit)
            conftest_cmd="$conftest_cmd --output junit"
            ;;
    esac
    
    # Add fail-on-warn flag
    if [[ "$FAIL_ON_WARN" == "true" ]]; then
        conftest_cmd="$conftest_cmd --fail-on-warn"
    fi
    
    # Add input file
    conftest_cmd="$conftest_cmd $INPUT_FILE"
    
    log_debug "Running command: $conftest_cmd"
    
    # Execute conftest
    local exit_code=0
    if [[ "$VERBOSE" == "true" ]]; then
        $conftest_cmd > "$temp_output" 2>&1 || exit_code=$?
    else
        $conftest_cmd > "$temp_output" 2>/dev/null || exit_code=$?
    fi
    
    # Handle exit codes
    case $exit_code in
        0)
            log_success "No violations found in $policy_dir"
            ;;
        1)
            log_warn "Policy violations found in $policy_dir"
            ;;
        *)
            log_error "Conftest failed with exit code $exit_code for $policy_dir"
            if [[ "$VERBOSE" != "true" ]]; then
                log_info "Run with -v flag for detailed error output"
            fi
            return $exit_code
            ;;
    esac
    
    return $exit_code
}

# Combine JSON results from multiple policy directories
combine_json_results() {
    local result_files=("$@")
    local combined_results="[]"
    
    log_info "Combining results from ${#result_files[@]} policy directories"
    
    for result_file in "${result_files[@]}"; do
        if [[ -f "$result_file" ]] && [[ -s "$result_file" ]]; then
            # Check if file contains valid JSON
            if jq empty "$result_file" 2>/dev/null; then
                # Combine results
                combined_results=$(jq -s 'add' <(echo "$combined_results") "$result_file")
            else
                log_warn "Skipping invalid JSON file: $result_file"
            fi
        fi
    done
    
    echo "$combined_results"
}

# Apply severity filtering to JSON results
apply_severity_filter() {
    local json_input="$1"
    
    if [[ "$SEVERITY_FILTER" == "all" ]]; then
        echo "$json_input"
        return 0
    fi
    
    log_info "Applying severity filter: $SEVERITY_FILTER"
    
    # Define severity levels and their numeric values for filtering
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
        *)
            log_error "Invalid severity filter: $SEVERITY_FILTER"
            echo "$json_input"
            return 1
            ;;
    esac
    
    # Apply filter and reconstruct array
    echo "$json_input" | jq "[$filter_query]"
}

# Generate summary statistics
generate_summary() {
    local json_results="$1"
    
    local total_violations
    total_violations=$(echo "$json_results" | jq 'length')
    
    local critical_count medium_count high_count low_count
    critical_count=$(echo "$json_results" | jq '[.[] | select(.severity == "CRITICAL")] | length')
    high_count=$(echo "$json_results" | jq '[.[] | select(.severity == "HIGH")] | length')
    medium_count=$(echo "$json_results" | jq '[.[] | select(.severity == "MEDIUM")] | length')
    low_count=$(echo "$json_results" | jq '[.[] | select(.severity == "LOW")] | length')
    
    log_info "Policy validation summary:"
    log_info "  Total violations: $total_violations"
    if [[ $critical_count -gt 0 ]]; then
        log_error "  Critical: $critical_count"
    fi
    if [[ $high_count -gt 0 ]]; then
        log_error "  High: $high_count"
    fi
    if [[ $medium_count -gt 0 ]]; then
        log_warn "  Medium: $medium_count"
    fi
    if [[ $low_count -gt 0 ]]; then
        log_info "  Low: $low_count"
    fi
    
    return $total_violations
}

# Run conftest on multiple policy directories
run_conftest_multiple() {
    local policy_dirs=("$@")
    local temp_files=()
    local exit_codes=()
    local final_exit_code=0
    
    # Create temporary directory for individual results
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Run conftest for each policy directory
    for i in "${!policy_dirs[@]}"; do
        local policy_dir="${policy_dirs[$i]}"
        local temp_output="$temp_dir/result_$i.${OUTPUT_FORMAT}"
        temp_files+=("$temp_output")
        
        local exit_code=0
        run_conftest_single "$policy_dir" "$temp_output" || exit_code=$?
        exit_codes+=($exit_code)
        
        if [[ $exit_code -gt $final_exit_code ]]; then
            final_exit_code=$exit_code
        fi
    done
    
    # Combine results if needed
    if [[ "$COMBINE_RESULTS" == "true" ]] && [[ "$OUTPUT_FORMAT" == "json" ]]; then
        log_info "Combining JSON results from all policy directories"
        local combined_json
        combined_json=$(combine_json_results "${temp_files[@]}")
        
        # Apply severity filtering
        combined_json=$(apply_severity_filter "$combined_json")
        
        # Write combined results
        echo "$combined_json" > "$OUTPUT_FILE"
        
        # Generate summary
        generate_summary "$combined_json" || final_exit_code=$?
        
    else
        # For non-JSON formats or when not combining, use the first result
        if [[ -f "${temp_files[0]}" ]]; then
            cp "${temp_files[0]}" "$OUTPUT_FILE"
        fi
    fi
    
    # Cleanup temporary files
    rm -rf "$temp_dir"
    
    return $final_exit_code
}

# Add metadata to JSON output
add_metadata_to_json() {
    local json_file="$1"
    
    if [[ "$OUTPUT_FORMAT" != "json" ]] || [[ ! -f "$json_file" ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local commit_hash
    commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    local conftest_version
    conftest_version=$(get_conftest_version)
    
    # Create metadata object
    local metadata
    metadata=$(cat << EOF
{
  "scan_metadata": {
    "timestamp": "$timestamp",
    "commit_hash": "$commit_hash",
    "conftest_version": "$conftest_version",
    "input_file": "$INPUT_FILE",
    "policy_directories": $(printf '%s\n' "${policy_dirs[@]}" | jq -R . | jq -s .),
    "severity_filter": "$SEVERITY_FILTER",
    "output_format": "$OUTPUT_FORMAT"
  }
}
EOF
)
    
    # Read current results
    local current_results
    current_results=$(cat "$json_file")
    
    # Combine metadata with results
    local final_json
    final_json=$(jq -s '.[0] + {"violations": .[1]}' <(echo "$metadata") <(echo "$current_results"))
    
    # Write back to file
    echo "$final_json" > "$json_file"
    
    log_debug "Added metadata to JSON output"
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting Conftest policy validation"
    
    # Check dependencies
    check_dependencies
    
    # Get conftest version
    local conftest_version
    conftest_version=$(get_conftest_version)
    log_info "Conftest Version: $conftest_version"
    
    # Validate inputs
    validate_input_file
    validate_output_format
    
    # Generate output file path
    generate_output_file
    
    log_info "Input File: $INPUT_FILE"
    log_info "Output File: $OUTPUT_FILE"
    log_info "Output Format: $OUTPUT_FORMAT"
    
    if [[ "$SEVERITY_FILTER" != "all" ]]; then
        log_info "Severity Filter: $SEVERITY_FILTER"
    fi
    
    # Discover policy directories
    local policy_dirs=()
    while IFS= read -r dir; do
        policy_dirs+=("$dir")
    done < <(discover_policy_directories)
    
    # Run conftest
    local exit_code=0
    if [[ ${#policy_dirs[@]} -eq 1 ]]; then
        run_conftest_single "${policy_dirs[0]}" "$OUTPUT_FILE" || exit_code=$?
    else
        run_conftest_multiple "${policy_dirs[@]}" || exit_code=$?
    fi
    
    # Add metadata to JSON output
    add_metadata_to_json "$OUTPUT_FILE"
    
    # Final status
    if [[ $exit_code -eq 0 ]]; then
        log_success "Policy validation completed successfully"
        log_success "Results saved to: $OUTPUT_FILE"
    else
        log_warn "Policy validation completed with violations"
        log_info "Results saved to: $OUTPUT_FILE"
    fi
    
    # Output the result file path for chaining
    echo "$OUTPUT_FILE"
    
    exit $exit_code
}

# Run main function
main "$@"