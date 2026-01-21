#!/bin/bash

# Run Property-Based Tests
# This script runs all property-based tests for the multi-cloud security policy system

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_ITERATIONS=100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Run property-based tests for the multi-cloud security policy system.

OPTIONS:
    -i, --iterations NUM    Number of iterations per test (default: $DEFAULT_ITERATIONS)
    -t, --test TEST_NAME    Run specific test only (policy-consistency, control-toggle, 
                           report-format, syntax-validation, no-credentials)
    -p, --parallel          Run tests in parallel (default: sequential)
    -v, --verbose           Verbose output
    -h, --help              Show this help message

EXAMPLES:
    $0                                    # Run all tests with default iterations
    $0 -i 50                             # Run all tests with 50 iterations each
    $0 -t policy-consistency             # Run only policy consistency test
    $0 -i 200 -p                         # Run all tests with 200 iterations in parallel
    $0 -t control-toggle -v              # Run control toggle test with verbose output

PROPERTY-BASED TESTS:
    policy-consistency    - Test policy evaluation consistency across environments
    control-toggle        - Test control enable/disable behavior
    report-format         - Test violation report completeness and format
    syntax-validation     - Test syntax error reporting quality
    no-credentials        - Test credential independence for basic operations

EOF
}

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [ "${VERBOSE:-false}" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Available property-based tests
PBT_TESTS=(
    "policy-consistency:Policy Evaluation Consistency"
    "control-toggle:Control Toggle Behavior"
    "report-format:Violation Report Completeness"
    "syntax-validation:Syntax Error Reporting"
    "no-credentials:Credential Independence"
)

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for required tools
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v bc >/dev/null 2>&1; then
        missing_deps+=("bc")
    fi
    
    # Check for test scripts
    for test_info in "${PBT_TESTS[@]}"; do
        local test_name=$(echo "$test_info" | cut -d: -f1)
        local test_script="$PROJECT_ROOT/tests/test-$test_name.sh"
        
        if [ ! -f "$test_script" ]; then
            missing_deps+=("test-$test_name.sh")
        elif [ ! -x "$test_script" ]; then
            log_warn "Making $test_script executable"
            chmod +x "$test_script"
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install missing tools and ensure test scripts exist"
        exit 1
    fi
}

# Run a single property-based test
run_single_test() {
    local test_name="$1"
    local test_title="$2"
    local iterations="$3"
    
    log_info "Running $test_title..."
    
    local test_script="$PROJECT_ROOT/tests/test-$test_name.sh"
    local start_time=$(date +%s)
    
    # Set environment variables
    export PBT_ITERATIONS="$iterations"
    
    # Run the test
    local test_result=0
    if [ "${VERBOSE:-false}" = true ]; then
        "$test_script" || test_result=$?
    else
        "$test_script" >/dev/null 2>&1 || test_result=$?
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Report results
    if [ $test_result -eq 0 ]; then
        log_info "✅ $test_title completed successfully in ${duration}s"
    else
        log_error "❌ $test_title failed in ${duration}s"
    fi
    
    return $test_result
}

# Run tests in parallel
run_tests_parallel() {
    local iterations="$1"
    local test_filter="$2"
    local pids=()
    local results=()
    
    log_info "Running property-based tests in parallel with $iterations iterations each..."
    
    # Start all tests
    for test_info in "${PBT_TESTS[@]}"; do
        local test_name=$(echo "$test_info" | cut -d: -f1)
        local test_title=$(echo "$test_info" | cut -d: -f2)
        
        # Skip if test filter is specified and doesn't match
        if [ -n "$test_filter" ] && [ "$test_name" != "$test_filter" ]; then
            continue
        fi
        
        log_info "Starting $test_title in background..."
        
        # Run test in background
        (
            export PBT_ITERATIONS="$iterations"
            "$PROJECT_ROOT/tests/test-$test_name.sh" >/dev/null 2>&1
            echo $? > "/tmp/pbt_result_$test_name.$$"
        ) &
        
        pids+=($!)
        results+=("$test_name:$test_title")
    done
    
    # Wait for all tests to complete
    local overall_result=0
    for i in "${!pids[@]}"; do
        local pid=${pids[$i]}
        local test_info=${results[$i]}
        local test_name=$(echo "$test_info" | cut -d: -f1)
        local test_title=$(echo "$test_info" | cut -d: -f2)
        
        wait $pid
        local test_result=$(cat "/tmp/pbt_result_$test_name.$$" 2>/dev/null || echo "1")
        rm -f "/tmp/pbt_result_$test_name.$$"
        
        if [ "$test_result" -eq 0 ]; then
            log_info "✅ $test_title completed successfully"
        else
            log_error "❌ $test_title failed"
            overall_result=1
        fi
    done
    
    return $overall_result
}

# Run tests sequentially
run_tests_sequential() {
    local iterations="$1"
    local test_filter="$2"
    local overall_result=0
    
    log_info "Running property-based tests sequentially with $iterations iterations each..."
    
    for test_info in "${PBT_TESTS[@]}"; do
        local test_name=$(echo "$test_info" | cut -d: -f1)
        local test_title=$(echo "$test_info" | cut -d: -f2)
        
        # Skip if test filter is specified and doesn't match
        if [ -n "$test_filter" ] && [ "$test_name" != "$test_filter" ]; then
            continue
        fi
        
        if ! run_single_test "$test_name" "$test_title" "$iterations"; then
            overall_result=1
        fi
    done
    
    return $overall_result
}

# Generate summary report
generate_summary() {
    local reports_dir="$PROJECT_ROOT/reports"
    local summary_file="$reports_dir/pbt_summary_$(date +%Y%m%d_%H%M%S).md"
    
    if [ ! -d "$reports_dir" ]; then
        return
    fi
    
    log_info "Generating property-based test summary..."
    
    cat > "$summary_file" << EOF
# Property-Based Test Summary

**Generated:** $(date)
**Command:** $0 $*

## Test Results

EOF
    
    local total_tests=0
    local passed_tests=0
    local total_iterations=0
    local total_passed_iterations=0
    local total_failed_iterations=0
    
    # Process each test type
    for test_info in "${PBT_TESTS[@]}"; do
        local test_name=$(echo "$test_info" | cut -d: -f1)
        local test_title=$(echo "$test_info" | cut -d: -f2)
        
        # Find latest result file - map test names to file patterns
        local file_pattern=""
        case "$test_name" in
            "policy-consistency")
                file_pattern="policy_consistency"
                ;;
            "control-toggle")
                file_pattern="control_toggle"
                ;;
            "report-format")
                file_pattern="report_format"
                ;;
            "syntax-validation")
                file_pattern="syntax_validation"
                ;;
            "no-credentials")
                file_pattern="credential_independence"
                ;;
        esac
        
        local latest_result=$(ls -t "$reports_dir"/pbt_*"$file_pattern"*.json 2>/dev/null | head -n1 || echo "")
        
        if [ -n "$latest_result" ] && [ -f "$latest_result" ]; then
            ((total_tests++))
            
            local test_total=$(jq -r '.summary.total' "$latest_result" 2>/dev/null || echo "0")
            local test_passed=$(jq -r '.summary.passed' "$latest_result" 2>/dev/null || echo "0")
            local test_failed=$(jq -r '.summary.failed' "$latest_result" 2>/dev/null || echo "0")
            local success_rate=$(jq -r '.summary.success_rate' "$latest_result" 2>/dev/null || echo "0")
            
            total_iterations=$((total_iterations + test_total))
            total_passed_iterations=$((total_passed_iterations + test_passed))
            total_failed_iterations=$((total_failed_iterations + test_failed))
            
            if [ "$test_failed" -eq 0 ]; then
                ((passed_tests++))
                echo "### ✅ $test_title" >> "$summary_file"
            else
                echo "### ❌ $test_title" >> "$summary_file"
            fi
            
            cat >> "$summary_file" << EOF

- **Total iterations:** $test_total
- **Passed:** $test_passed
- **Failed:** $test_failed
- **Success rate:** $success_rate%

EOF
        else
            echo "### ⚠️ $test_title" >> "$summary_file"
            echo "" >> "$summary_file"
            echo "- **Status:** No results found" >> "$summary_file"
            echo "" >> "$summary_file"
        fi
    done
    
    # Add overall summary
    cat >> "$summary_file" << EOF
## Overall Summary

- **Total test types:** $total_tests
- **Passed test types:** $passed_tests
- **Total iterations:** $total_iterations
- **Passed iterations:** $total_passed_iterations
- **Failed iterations:** $total_failed_iterations

EOF
    
    if [ $total_iterations -gt 0 ]; then
        local overall_success_rate=$(echo "scale=2; $total_passed_iterations * 100 / $total_iterations" | bc -l)
        echo "- **Overall success rate:** $overall_success_rate%" >> "$summary_file"
    fi
    
    log_info "Summary report saved to: $summary_file"
}

# Main function
main() {
    local iterations="$DEFAULT_ITERATIONS"
    local test_filter=""
    local parallel=false
    local verbose=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--iterations)
                iterations="$2"
                shift 2
                ;;
            -t|--test)
                test_filter="$2"
                shift 2
                ;;
            -p|--parallel)
                parallel=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                export VERBOSE=true
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
    
    # Validate iterations
    if ! [[ "$iterations" =~ ^[0-9]+$ ]] || [ "$iterations" -lt 1 ]; then
        log_error "Invalid iterations: $iterations (must be a positive integer)"
        exit 1
    fi
    
    # Validate test filter
    if [ -n "$test_filter" ]; then
        local valid_test=false
        for test_info in "${PBT_TESTS[@]}"; do
            local test_name=$(echo "$test_info" | cut -d: -f1)
            if [ "$test_name" = "$test_filter" ]; then
                valid_test=true
                break
            fi
        done
        
        if [ "$valid_test" = false ]; then
            log_error "Invalid test name: $test_filter"
            log_error "Available tests: $(printf '%s ' "${PBT_TESTS[@]}" | sed 's/:[^:]*//g')"
            exit 1
        fi
    fi
    
    # Check dependencies
    check_dependencies
    
    # Create reports directory
    mkdir -p "$PROJECT_ROOT/reports"
    
    # Run tests
    local start_time=$(date +%s)
    local overall_result=0
    
    if [ "$parallel" = true ]; then
        run_tests_parallel "$iterations" "$test_filter" || overall_result=$?
    else
        run_tests_sequential "$iterations" "$test_filter" || overall_result=$?
    fi
    
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Generate summary
    generate_summary
    
    # Final report
    log_info "Property-based testing completed in ${total_duration}s"
    
    if [ $overall_result -eq 0 ]; then
        log_info "✅ All property-based tests passed"
    else
        log_error "❌ Some property-based tests failed"
        log_info "Check individual test reports in $PROJECT_ROOT/reports/ for details"
    fi
    
    exit $overall_result
}

# Run main function
main "$@"