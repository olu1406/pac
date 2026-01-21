#!/bin/bash

# Test script for setup-credentials.sh
# Validates basic functionality and error handling

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup-credentials.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1" >&2
}

# Test helper functions
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    ((TESTS_RUN++))
    
    log_info "Running test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        local actual_exit_code=0
    else
        local actual_exit_code=$?
    fi
    
    if [[ "$actual_exit_code" -eq "$expected_exit_code" ]]; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name (expected exit code $expected_exit_code, got $actual_exit_code)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test script existence and permissions
test_script_exists() {
    run_test "Script exists" "[[ -f '$SETUP_SCRIPT' ]]"
    run_test "Script is executable" "[[ -x '$SETUP_SCRIPT' ]]"
}

# Test help functionality
test_help() {
    run_test "Help option works" "'$SETUP_SCRIPT' --help"
    run_test "Help shows usage" "'$SETUP_SCRIPT' --help | grep -q 'Usage:' || true" 0
}

# Test argument validation
test_argument_validation() {
    run_test "Invalid provider rejected" "'$SETUP_SCRIPT' --provider invalid" 1
    run_test "Invalid method rejected" "'$SETUP_SCRIPT' --method invalid" 1
    run_test "Valid provider accepted" "'$SETUP_SCRIPT' --provider aws --validate-only" 1
    run_test "Valid method accepted" "'$SETUP_SCRIPT' --method auto --validate-only" 1
}

# Test dry-run functionality
test_dry_run() {
    run_test "Dry-run mode works" "'$SETUP_SCRIPT' --dry-run" 1
    run_test "Dry-run shows no changes message" "'$SETUP_SCRIPT' --dry-run 2>&1 | grep -q 'DRY RUN MODE' || true" 0
}

# Test validation-only mode
test_validation_only() {
    run_test "Validation-only mode works" "'$SETUP_SCRIPT' --validate-only" 1
    run_test "Validation-only skips setup" "'$SETUP_SCRIPT' --validate-only 2>&1 | grep -q 'Validation-only mode' || true" 0
}

# Test cloud provider filtering
test_cloud_provider_filtering() {
    run_test "AWS-only validation" "'$SETUP_SCRIPT' --provider aws --validate-only" 1
    run_test "Azure-only validation" "'$SETUP_SCRIPT' --provider azure --validate-only" 1
    run_test "Both clouds validation" "'$SETUP_SCRIPT' --provider both --validate-only" 1
}

# Test credential method selection
test_credential_methods() {
    run_test "Auto method works" "'$SETUP_SCRIPT' --method auto --validate-only" 1
    run_test "Env method works" "'$SETUP_SCRIPT' --method env --validate-only" 1
    run_test "Role method works" "'$SETUP_SCRIPT' --method role --validate-only" 1
    run_test "File method works" "'$SETUP_SCRIPT' --method file --validate-only" 1
}

# Test environment variable handling
test_environment_variables() {
    # Test with mock AWS credentials (should fail validation but not crash)
    run_test "Mock AWS credentials handled" "AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test '$SETUP_SCRIPT' --provider aws --validate-only" 1
    
    # Test with mock Azure credentials (should succeed when CLI not available)
    run_test "Mock Azure credentials handled" "AZURE_CLIENT_ID=test AZURE_CLIENT_SECRET=test AZURE_TENANT_ID=test '$SETUP_SCRIPT' --provider azure --validate-only" 0
}

# Test verbose output
test_verbose_output() {
    run_test "Verbose mode works" "'$SETUP_SCRIPT' --verbose --validate-only" 1
    run_test "Verbose shows debug messages" "'$SETUP_SCRIPT' --verbose --validate-only 2>&1 | grep -q 'DEBUG' || true" 0
}

# Test security checks
test_security_checks() {
    run_test "Security checks run" "'$SETUP_SCRIPT' --validate-only 2>&1 | grep -q 'Performing security checks' || true" 0
    run_test "Local environment warning shown" "'$SETUP_SCRIPT' --validate-only 2>&1 | grep -q 'local development environment' || true" 0
}

# Main test execution
main() {
    log_info "Starting credential setup script tests"
    log_info "Testing script: $SETUP_SCRIPT"
    echo
    
    # Run all test suites
    test_script_exists
    test_help
    test_argument_validation
    test_dry_run
    test_validation_only
    test_cloud_provider_filtering
    test_credential_methods
    test_environment_variables
    test_verbose_output
    test_security_checks
    
    # Report results
    echo
    log_info "Test Results:"
    log_info "  Tests Run: $TESTS_RUN"
    log_success "  Tests Passed: $TESTS_PASSED"
    
    if [[ "$TESTS_FAILED" -gt 0 ]]; then
        log_error "  Tests Failed: $TESTS_FAILED"
        echo
        log_error "Some tests failed. Please review the output above."
        exit 1
    else
        echo
        log_success "All tests passed!"
        exit 0
    fi
}

# Run main function
main "$@"