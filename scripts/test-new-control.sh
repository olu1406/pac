#!/bin/bash

# Test script for new-control.sh validation
# This script tests the control scaffolding functionality

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

# Test 1: Help function
test_help() {
    log_info "Testing help function..."
    if ./scripts/new-control.sh --help > /dev/null 2>&1; then
        log_success "Help function works"
        return 0
    else
        log_error "Help function failed"
        return 1
    fi
}

# Test 2: Validation functions
test_validation() {
    log_info "Testing validation functions..."
    
    # Test invalid cloud provider
    if ./scripts/new-control.sh --cloud invalid --non-interactive 2>/dev/null; then
        log_error "Should reject invalid cloud provider"
        return 1
    else
        log_success "Correctly rejects invalid cloud provider"
    fi
    
    return 0
}

# Test 3: Control ID generation
test_control_id_generation() {
    log_info "Testing control ID generation..."
    
    # This test would require more complex setup
    # For now, just verify the script can be called with valid parameters
    local test_output
    test_output=$(./scripts/new-control.sh --cloud aws --domain identity --number 999 \
        --title "Test Control" --severity HIGH --frameworks "nist:AC-2" \
        --description "Test description" --remediation "Test remediation" \
        --non-interactive 2>&1 || true)
    
    if echo "$test_output" | grep -q "Control ID: IAM-999"; then
        log_success "Control ID generation works"
        
        # Clean up test files
        rm -f "policies/aws/identity/identity_policies.rego"
        if [[ -f "policies/control_metadata.json.backup" ]]; then
            cp "policies/control_metadata.json.backup" "policies/control_metadata.json"
        fi
        
        return 0
    else
        log_error "Control ID generation failed"
        return 1
    fi
}

# Test 4: Framework parsing
test_framework_parsing() {
    log_info "Testing framework parsing..."
    
    # Test the parse_frameworks function indirectly by checking output
    local test_output
    test_output=$(./scripts/new-control.sh --cloud aws --domain data --number 998 \
        --title "Test Framework Parsing" --severity MEDIUM \
        --frameworks "nist:AC-2,cis-aws:1.1,iso:A.9.2.1" \
        --description "Test description" --remediation "Test remediation" \
        --non-interactive 2>&1 || true)
    
    if echo "$test_output" | grep -q "Control.*created successfully"; then
        log_success "Framework parsing works"
        
        # Clean up test files
        rm -f "policies/aws/data/data_policies.rego"
        if [[ -f "policies/control_metadata.json.backup" ]]; then
            cp "policies/control_metadata.json.backup" "policies/control_metadata.json"
        fi
        
        return 0
    else
        log_error "Framework parsing failed"
        return 1
    fi
}

# Main test execution
main() {
    log_info "Starting new-control.sh validation tests..."
    echo
    
    local failed_tests=0
    
    # Run tests
    test_help || ((failed_tests++))
    test_validation || ((failed_tests++))
    test_control_id_generation || ((failed_tests++))
    test_framework_parsing || ((failed_tests++))
    
    echo
    if [[ $failed_tests -eq 0 ]]; then
        log_success "All tests passed! The new-control.sh script is working correctly."
        return 0
    else
        log_error "$failed_tests test(s) failed. Please check the script implementation."
        return 1
    fi
}

# Run tests
main "$@"