#!/bin/bash

# Policy Syntax Validation Script
# Validates Rego policy syntax using OPA/Conftest with detailed error reporting

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="${POLICIES_DIR:-$PROJECT_ROOT/policies}"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/reports}"

# Default configuration
POLICY_DIRS="${POLICY_DIRS:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
FAIL_FAST="${FAIL_FAST:-false}"
VERBOSE="${VERBOSE:-false}"
CHECK_IMPORTS="${CHECK_IMPORTS:-true}"
CHECK_METADATA="${CHECK_METADATA:-true}"

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

Validate Rego policy syntax using OPA/Conftest with detailed error reporting.

OPTIONS:
    -p, --policy-dirs DIRS      Comma-separated policy directories (default: auto-discover)
    -o, --output FILE           Output file for validation results (default: auto-generated)
    -f, --format FORMAT         Output format: json, table (default: json)
    -F, --fail-fast             Stop on first validation error (default: false)
    --no-imports                Skip import validation
    --no-metadata               Skip metadata validation
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                                          # Validate all policies
    $0 -p policies/aws,policies/azure          # Validate specific directories
    $0 -f table                                # Output in table format
    $0 -F                                       # Stop on first error
    $0 -o validation_results.json              # Save results to specific file

ENVIRONMENT VARIABLES:
    POLICY_DIRS                 Override policy directories
    OUTPUT_FILE                 Override output file
    OUTPUT_FORMAT               Override output format
    FAIL_FAST                   Stop on first error (true/false)
    VERBOSE                     Enable verbose output (true/false)
    CHECK_IMPORTS               Check import statements (true/false)
    CHECK_METADATA              Check control metadata (true/false)
    POLICIES_DIR                Override base policies directory
    REPORTS_DIR                 Override reports directory

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--policy-dirs)
                POLICY_DIRS="$2"
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
            -F|--fail-fast)
                FAIL_FAST="true"
                shift
                ;;
            --no-imports)
                CHECK_IMPORTS="false"
                shift
                ;;
            --no-metadata)
                CHECK_METADATA="false"
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
    local missing_deps=()
    
    if ! command -v opa &> /dev/null; then
        missing_deps+=("opa")
    fi
    
    if ! command -v conftest &> /dev/null; then
        missing_deps+=("conftest")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Installation instructions:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                opa)
                    log_info "  OPA: https://www.openpolicyagent.org/docs/latest/#running-opa"
                    ;;
                conftest)
                    log_info "  Conftest: https://www.conftest.dev/install/"
                    ;;
                jq)
                    log_info "  jq: https://stedolan.github.io/jq/download/"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_debug "Dependencies validated successfully"
}

# Get tool versions
get_tool_versions() {
    local opa_version conftest_version jq_version
    
    opa_version=$(opa version --format json 2>/dev/null | jq -r '.Version' || echo "unknown")
    conftest_version=$(conftest --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
    jq_version=$(jq --version 2>/dev/null | sed 's/jq-//' || echo "unknown")
    
    log_info "Tool versions:"
    log_info "  OPA: $opa_version"
    log_info "  Conftest: $conftest_version"
    log_info "  jq: $jq_version"
}

# Discover policy files
discover_policy_files() {
    local discovered_files=()
    
    if [[ -n "$POLICY_DIRS" ]]; then
        # Use specified directories
        IFS=',' read -ra dirs <<< "$POLICY_DIRS"
        for dir in "${dirs[@]}"; do
            dir=$(echo "$dir" | xargs)  # Trim whitespace
            if [[ -d "$dir" ]]; then
                while IFS= read -r -d '' file; do
                    discovered_files+=("$file")
                done < <(find "$dir" -name "*.rego" -type f -print0)
            else
                log_warn "Policy directory not found: $dir"
            fi
        done
    else
        # Auto-discover policy files
        if [[ -d "$POLICIES_DIR" ]]; then
            while IFS= read -r -d '' file; do
                discovered_files+=("$file")
            done < <(find "$POLICIES_DIR" -name "*.rego" -type f -print0)
        fi
    fi
    
    if [[ ${#discovered_files[@]} -eq 0 ]]; then
        log_error "No policy files found"
        log_info "Searched in: $POLICIES_DIR"
        if [[ -n "$POLICY_DIRS" ]]; then
            log_info "Specified directories: $POLICY_DIRS"
        fi
        exit 1
    fi
    
    log_info "Found ${#discovered_files[@]} policy files"
    
    printf '%s\n' "${discovered_files[@]}"
}

# Validate single policy file syntax using OPA
validate_opa_syntax() {
    local policy_file="$1"
    local validation_result=()
    
    log_debug "Validating OPA syntax: $policy_file"
    
    # Use OPA to parse and validate syntax
    local opa_output opa_exit_code=0
    opa_output=$(opa parse "$policy_file" 2>&1) || opa_exit_code=$?
    
    if [[ $opa_exit_code -ne 0 ]]; then
        # Parse OPA error output to extract line numbers and details
        local error_line error_message
        if [[ "$opa_output" =~ ([0-9]+):([0-9]+):(.+) ]]; then
            error_line="${BASH_REMATCH[1]}"
            error_message="${BASH_REMATCH[3]}"
        else
            error_line="unknown"
            error_message="$opa_output"
        fi
        
        validation_result+=('{
            "type": "syntax_error",
            "severity": "CRITICAL",
            "file": "'"$policy_file"'",
            "line": '"${error_line:-0}"',
            "message": "'"$(echo "$error_message" | sed 's/"/\\"/g' | tr -d '\n')"'",
            "tool": "opa"
        }')
    fi
    
    printf '%s\n' "${validation_result[@]}"
}

# Validate policy file using Conftest
validate_conftest_syntax() {
    local policy_file="$1"
    local validation_result=()
    
    log_debug "Validating Conftest syntax: $policy_file"
    
    # Create a minimal test input for conftest
    local temp_input
    temp_input=$(mktemp)
    echo '{}' > "$temp_input"
    
    # Use conftest to validate policy
    local conftest_output conftest_exit_code=0
    conftest_output=$(conftest verify --policy "$(dirname "$policy_file")" "$temp_input" 2>&1) || conftest_exit_code=$?
    
    # Clean up temp file
    rm -f "$temp_input"
    
    # Check for policy loading errors (not rule violations)
    if [[ $conftest_exit_code -gt 1 ]] || [[ "$conftest_output" =~ "error loading policy" ]]; then
        local error_message
        error_message=$(echo "$conftest_output" | grep -E "(error|Error)" | head -n1 || echo "$conftest_output")
        
        validation_result+=('{
            "type": "policy_error",
            "severity": "HIGH",
            "file": "'"$policy_file"'",
            "line": 0,
            "message": "'"$(echo "$error_message" | sed 's/"/\\"/g' | tr -d '\n')"'",
            "tool": "conftest"
        }')
    fi
    
    printf '%s\n' "${validation_result[@]}"
}

# Validate import statements
validate_imports() {
    local policy_file="$1"
    local validation_result=()
    
    if [[ "$CHECK_IMPORTS" != "true" ]]; then
        return 0
    fi
    
    log_debug "Validating imports: $policy_file"
    
    # Check for required imports
    local has_rego_v1=false
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*import[[:space:]]+rego\.v1 ]]; then
            has_rego_v1=true
        fi
    done < "$policy_file"
    
    # Check if file contains rules but no rego.v1 import
    if ! $has_rego_v1 && grep -q -E '^[[:space:]]*(deny|allow|violation|warn)[[:space:]]*[{:]' "$policy_file"; then
        validation_result+=('{
            "type": "import_warning",
            "severity": "MEDIUM",
            "file": "'"$policy_file"'",
            "line": 1,
            "message": "Policy file should import rego.v1 for best practices",
            "tool": "import_checker"
        }')
    fi
    
    printf '%s\n' "${validation_result[@]}"
}

# Validate control metadata
validate_metadata() {
    local policy_file="$1"
    local validation_result=()
    
    if [[ "$CHECK_METADATA" != "true" ]]; then
        return 0
    fi
    
    log_debug "Validating metadata: $policy_file"
    
    local line_num=0
    local has_control_id=false
    local has_title=false
    local has_severity=false
    local has_frameworks=false
    local has_status=false
    
    while IFS= read -r line; do
        ((line_num++))
        
        if [[ "$line" =~ ^#[[:space:]]*CONTROL:[[:space:]]*(.+) ]]; then
            has_control_id=true
        elif [[ "$line" =~ ^#[[:space:]]*TITLE:[[:space:]]*(.+) ]]; then
            has_title=true
        elif [[ "$line" =~ ^#[[:space:]]*SEVERITY:[[:space:]]*(CRITICAL|HIGH|MEDIUM|LOW) ]]; then
            has_severity=true
        elif [[ "$line" =~ ^#[[:space:]]*FRAMEWORKS:[[:space:]]*(.+) ]]; then
            has_frameworks=true
        elif [[ "$line" =~ ^#[[:space:]]*STATUS:[[:space:]]*(ENABLED|DISABLED) ]]; then
            has_status=true
        fi
        
        # Stop checking after we've seen some Rego code
        if [[ "$line" =~ ^[[:space:]]*(package|import|deny|allow) ]] && [[ $line_num -gt 20 ]]; then
            break
        fi
    done < "$policy_file"
    
    # Check for missing required metadata
    if ! $has_control_id; then
        validation_result+=('{
            "type": "metadata_error",
            "severity": "HIGH",
            "file": "'"$policy_file"'",
            "line": 1,
            "message": "Missing required CONTROL metadata",
            "tool": "metadata_checker"
        }')
    fi
    
    if ! $has_title; then
        validation_result+=('{
            "type": "metadata_error",
            "severity": "MEDIUM",
            "file": "'"$policy_file"'",
            "line": 1,
            "message": "Missing TITLE metadata",
            "tool": "metadata_checker"
        }')
    fi
    
    if ! $has_severity; then
        validation_result+=('{
            "type": "metadata_error",
            "severity": "MEDIUM",
            "file": "'"$policy_file"'",
            "line": 1,
            "message": "Missing SEVERITY metadata",
            "tool": "metadata_checker"
        }')
    fi
    
    if ! $has_frameworks; then
        validation_result+=('{
            "type": "metadata_warning",
            "severity": "LOW",
            "file": "'"$policy_file"'",
            "line": 1,
            "message": "Missing FRAMEWORKS metadata",
            "tool": "metadata_checker"
        }')
    fi
    
    if ! $has_status; then
        validation_result+=('{
            "type": "metadata_warning",
            "severity": "LOW",
            "file": "'"$policy_file"'",
            "line": 1,
            "message": "Missing STATUS metadata",
            "tool": "metadata_checker"
        }')
    fi
    
    printf '%s\n' "${validation_result[@]}"
}

# Validate single policy file
validate_policy_file() {
    local policy_file="$1"
    local all_results=()
    
    log_debug "Validating policy file: $policy_file"
    
    # Check if file exists and is readable
    if [[ ! -f "$policy_file" ]]; then
        echo '{
            "type": "file_error",
            "severity": "CRITICAL",
            "file": "'"$policy_file"'",
            "line": 0,
            "message": "Policy file not found",
            "tool": "file_checker"
        }'
        return 1
    fi
    
    if [[ ! -r "$policy_file" ]]; then
        echo '{
            "type": "file_error",
            "severity": "CRITICAL",
            "file": "'"$policy_file"'",
            "line": 0,
            "message": "Policy file not readable",
            "tool": "file_checker"
        }'
        return 1
    fi
    
    # Validate OPA syntax
    local opa_results
    readarray -t opa_results < <(validate_opa_syntax "$policy_file")
    all_results+=("${opa_results[@]}")
    
    # If OPA syntax is valid, run additional checks
    if [[ ${#opa_results[@]} -eq 0 ]]; then
        # Validate with Conftest
        local conftest_results
        readarray -t conftest_results < <(validate_conftest_syntax "$policy_file")
        all_results+=("${conftest_results[@]}")
        
        # Validate imports
        local import_results
        readarray -t import_results < <(validate_imports "$policy_file")
        all_results+=("${import_results[@]}")
        
        # Validate metadata
        local metadata_results
        readarray -t metadata_results < <(validate_metadata "$policy_file")
        all_results+=("${metadata_results[@]}")
    fi
    
    # Output results
    printf '%s\n' "${all_results[@]}"
    
    # Return error code if any critical or high severity issues found
    local has_errors=false
    for result in "${all_results[@]}"; do
        if [[ -n "$result" ]] && echo "$result" | jq -e '.severity == "CRITICAL" or .severity == "HIGH"' >/dev/null 2>&1; then
            has_errors=true
            break
        fi
    done
    
    if $has_errors; then
        return 1
    else
        return 0
    fi
}

# Generate output file path
generate_output_file() {
    if [[ -n "$OUTPUT_FILE" ]]; then
        return 0
    fi
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    case "$OUTPUT_FORMAT" in
        json)
            OUTPUT_FILE="$REPORTS_DIR/policy_validation_${timestamp}.json"
            ;;
        table)
            OUTPUT_FILE="$REPORTS_DIR/policy_validation_${timestamp}.txt"
            ;;
    esac
    
    log_debug "Generated output file: $OUTPUT_FILE"
}

# Format results as table
format_table_output() {
    local json_results="$1"
    local output_file="$2"
    
    {
        echo "Policy Validation Results"
        echo "========================="
        echo
        
        # Summary
        local total_files total_errors total_warnings
        total_files=$(echo "$json_results" | jq '[.violations[] | .file] | unique | length')
        total_errors=$(echo "$json_results" | jq '[.violations[] | select(.severity == "CRITICAL" or .severity == "HIGH")] | length')
        total_warnings=$(echo "$json_results" | jq '[.violations[] | select(.severity == "MEDIUM" or .severity == "LOW")] | length')
        
        echo "Summary:"
        echo "  Files validated: $total_files"
        echo "  Errors: $total_errors"
        echo "  Warnings: $total_warnings"
        echo
        
        # Group by file
        local files
        readarray -t files < <(echo "$json_results" | jq -r '[.violations[] | .file] | unique | .[]')
        
        for file in "${files[@]}"; do
            echo "File: $file"
            echo "$(printf '%.0s-' {1..80})"
            
            # Get violations for this file
            local file_violations
            file_violations=$(echo "$json_results" | jq --arg file "$file" '[.violations[] | select(.file == $file)]')
            
            echo "$file_violations" | jq -r '.[] | "  Line \(.line): [\(.severity)] \(.message) (\(.tool))"'
            echo
        done
        
    } > "$output_file"
}

# Add metadata to JSON output
add_metadata_to_json() {
    local json_file="$1"
    local policy_files=("${@:2}")
    
    if [[ "$OUTPUT_FORMAT" != "json" ]] || [[ ! -f "$json_file" ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local commit_hash
    commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    local opa_version conftest_version
    opa_version=$(opa version --format json 2>/dev/null | jq -r '.Version' || echo "unknown")
    conftest_version=$(conftest --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
    
    # Create metadata object
    local metadata
    metadata=$(cat << EOF
{
  "validation_metadata": {
    "timestamp": "$timestamp",
    "commit_hash": "$commit_hash",
    "opa_version": "$opa_version",
    "conftest_version": "$conftest_version",
    "total_files": ${#policy_files[@]},
    "check_imports": $CHECK_IMPORTS,
    "check_metadata": $CHECK_METADATA
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

# Generate summary statistics
generate_summary() {
    local json_results="$1"
    
    local total_files total_violations total_errors total_warnings
    total_files=$(echo "$json_results" | jq '[.violations[] | .file] | unique | length')
    total_violations=$(echo "$json_results" | jq '.violations | length')
    total_errors=$(echo "$json_results" | jq '[.violations[] | select(.severity == "CRITICAL" or .severity == "HIGH")] | length')
    total_warnings=$(echo "$json_results" | jq '[.violations[] | select(.severity == "MEDIUM" or .severity == "LOW")] | length')
    
    log_info "Policy validation summary:"
    log_info "  Files validated: $total_files"
    log_info "  Total issues: $total_violations"
    
    if [[ $total_errors -gt 0 ]]; then
        log_error "  Errors (Critical/High): $total_errors"
    fi
    
    if [[ $total_warnings -gt 0 ]]; then
        log_warn "  Warnings (Medium/Low): $total_warnings"
    fi
    
    return $total_errors
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting policy syntax validation"
    
    # Check dependencies
    check_dependencies
    
    # Get tool versions
    get_tool_versions
    
    # Generate output file path
    generate_output_file
    
    log_info "Output File: $OUTPUT_FILE"
    log_info "Output Format: $OUTPUT_FORMAT"
    
    # Discover policy files
    local policy_files
    readarray -t policy_files < <(discover_policy_files)
    
    log_info "Validating ${#policy_files[@]} policy files"
    
    # Validate all policy files
    local all_results=()
    local failed_files=0
    local total_files=${#policy_files[@]}
    
    for policy_file in "${policy_files[@]}"; do
        log_debug "Processing: $policy_file"
        
        local file_results exit_code=0
        readarray -t file_results < <(validate_policy_file "$policy_file") || exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            ((failed_files++))
            if [[ "$FAIL_FAST" == "true" ]]; then
                log_error "Validation failed for $policy_file (fail-fast enabled)"
                break
            fi
        fi
        
        all_results+=("${file_results[@]}")
    done
    
    # Combine all results into JSON array
    local combined_json="[]"
    for result in "${all_results[@]}"; do
        if [[ -n "$result" ]]; then
            combined_json=$(echo "$combined_json" | jq ". + [$result]")
        fi
    done
    
    # Output results based on format
    case "$OUTPUT_FORMAT" in
        json)
            echo "$combined_json" > "$OUTPUT_FILE"
            add_metadata_to_json "$OUTPUT_FILE" "${policy_files[@]}"
            ;;
        table)
            local temp_json
            temp_json=$(mktemp)
            echo "{\"violations\": $combined_json}" > "$temp_json"
            format_table_output "$(cat "$temp_json")" "$OUTPUT_FILE"
            rm -f "$temp_json"
            ;;
    esac
    
    # Generate summary
    local summary_json="{\"violations\": $combined_json}"
    local exit_code=0
    generate_summary "$summary_json" || exit_code=$?
    
    # Final status
    if [[ $exit_code -eq 0 ]]; then
        log_success "Policy validation completed successfully"
        log_success "Results saved to: $OUTPUT_FILE"
    else
        log_warn "Policy validation completed with errors"
        log_info "Results saved to: $OUTPUT_FILE"
    fi
    
    # Output the result file path for chaining
    echo "$OUTPUT_FILE"
    
    exit $exit_code
}

# Run main function
main "$@"