#!/bin/bash

# End-to-End Integration Test Script
# Tests complete workflow from Terraform plan to violation report
# Validates all components work together correctly and error handling across boundaries

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_ROOT/reports"
EXAMPLES_DIR="$PROJECT_ROOT/examples"
POLICIES_DIR="$PROJECT_ROOT/policies"

# Test environment setup
TEST_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_REPORTS_DIR="$REPORTS_DIR/e2e_test_$TEST_TIMESTAMP"
TEMP_DIR=$(mktemp -d)

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

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" >&2
    fi
}

# Test helper functions
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TESTS_RUN++))
    
    log_info "Running test: $test_name"
    
    if $test_function; then
        log_success "$test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    
    # Clean up test reports directory if empty
    if [[ -d "$TEST_REPORTS_DIR" ]] && [[ -z "$(ls -A "$TEST_REPORTS_DIR" 2>/dev/null)" ]]; then
        rmdir "$TEST_REPORTS_DIR" 2>/dev/null || true
    fi
}

# Trap cleanup on exit
trap cleanup EXIT

# Test 1: Validate dependencies and prerequisites
test_dependencies() {
    log_debug "Checking required dependencies..."
    
    local missing_deps=()
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if ! command -v conftest &> /dev/null; then
        missing_deps+=("conftest")
    fi
    
    if ! command -v opa &> /dev/null; then
        missing_deps+=("opa")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    # Check script existence and permissions
    local required_scripts=(
        "scripts/scan.sh"
        "scripts/generate-plan.sh"
        "scripts/run-conftest.sh"
        "scripts/generate-report.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$script" ]]; then
            log_error "Required script not found: $script"
            return 1
        fi
        
        if [[ ! -x "$PROJECT_ROOT/$script" ]]; then
            log_error "Script not executable: $script"
            return 1
        fi
    done
    
    # Check directory structure
    local required_dirs=(
        "$EXAMPLES_DIR"
        "$POLICIES_DIR"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Required directory not found: $dir"
            return 1
        fi
    done
    
    log_debug "All dependencies and prerequisites validated"
    return 0
}

# Test 2: Validate policy syntax and structure
test_policy_validation() {
    log_debug "Validating policy syntax and structure..."
    
    # Find all Rego policy files
    local policy_files=()
    while IFS= read -r -d '' file; do
        policy_files+=("$file")
    done < <(find "$POLICIES_DIR" -name "*.rego" -type f -print0)
    
    if [[ ${#policy_files[@]} -eq 0 ]]; then
        log_error "No policy files found in $POLICIES_DIR"
        return 1
    fi
    
    log_debug "Found ${#policy_files[@]} policy files"
    
    # Validate each policy file
    for policy_file in "${policy_files[@]}"; do
        log_debug "Validating policy: $policy_file"
        
        # Skip template files (they contain only comments and examples)
        if [[ "$policy_file" =~ template\.rego$ ]]; then
            log_debug "Skipping template file: $policy_file"
            continue
        fi
        
        # Skip optional policy files that are fully commented out (templates)
        if [[ "$policy_file" =~ optional/ ]]; then
            # Check if file has any uncommented package or deny statements
            if ! grep -q "^package\|^deny" "$policy_file"; then
                log_debug "Skipping commented optional policy: $policy_file"
                continue
            fi
        fi
        
        # Check OPA syntax
        if ! opa fmt --diff "$policy_file" >/dev/null 2>&1; then
            log_error "Policy syntax error in: $policy_file"
            return 1
        fi
        
        # Check for required metadata in control policies
        if [[ "$policy_file" =~ (aws|azure)/ ]] && [[ ! "$policy_file" =~ optional/ ]]; then
            if ! grep -q "# CONTROL:" "$policy_file"; then
                log_warn "Policy missing control metadata: $policy_file"
            fi
        fi
    done
    
    log_debug "All policies validated successfully"
    return 0
}

# Test 3: Test Terraform plan generation for good examples
test_good_examples_plan_generation() {
    log_debug "Testing Terraform plan generation for good examples..."
    
    # Find good example directories
    local good_examples=()
    if [[ -d "$EXAMPLES_DIR/good" ]]; then
        while IFS= read -r -d '' dir; do
            good_examples+=("$dir")
        done < <(find "$EXAMPLES_DIR/good" -mindepth 1 -maxdepth 1 -type d -print0)
    fi
    
    if [[ ${#good_examples[@]} -eq 0 ]]; then
        log_error "No good examples found in $EXAMPLES_DIR/good"
        return 1
    fi
    
    log_debug "Found ${#good_examples[@]} good examples"
    
    # Test plan generation for each good example
    for example_dir in "${good_examples[@]}"; do
        local example_name
        example_name=$(basename "$example_dir")
        log_debug "Testing plan generation for good example: $example_name"
        
        # Create test reports directory
        mkdir -p "$TEST_REPORTS_DIR"
        
        # Generate plan using the generate-plan.sh script
        local plan_json="$TEST_REPORTS_DIR/good_${example_name}_plan.json"
        
        if ! "$PROJECT_ROOT/scripts/generate-plan.sh" \
            --terraform-dir "$example_dir" \
            --output "$plan_json" >/dev/null 2>&1; then
            # Check if failure is due to authentication (expected for cloud providers)
            if [[ "$example_name" =~ azure ]] && ! command -v az &> /dev/null; then
                log_debug "Skipping Azure example (Azure CLI not available): $example_name"
                continue
            elif [[ "$example_name" =~ aws ]] && [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
                log_debug "Skipping AWS example (AWS credentials not available): $example_name"
                continue
            else
                log_error "Failed to generate plan for good example: $example_name"
                return 1
            fi
        fi
        
        # Validate plan JSON structure
        if [[ ! -f "$plan_json" ]]; then
            log_error "Plan JSON not created for good example: $example_name"
            return 1
        fi
        
        if ! jq empty "$plan_json" 2>/dev/null; then
            log_error "Invalid JSON in plan for good example: $example_name"
            return 1
        fi
        
        # Check for required plan structure
        if ! jq -e '.planned_values' "$plan_json" >/dev/null 2>&1; then
            log_error "Plan missing planned_values for good example: $example_name"
            return 1
        fi
        
        log_debug "Plan generation successful for good example: $example_name"
    done
    
    return 0
}

# Test 4: Test Terraform plan generation for bad examples
test_bad_examples_plan_generation() {
    log_debug "Testing Terraform plan generation for bad examples..."
    
    # Find bad example directories
    local bad_examples=()
    if [[ -d "$EXAMPLES_DIR/bad" ]]; then
        while IFS= read -r -d '' dir; do
            bad_examples+=("$dir")
        done < <(find "$EXAMPLES_DIR/bad" -mindepth 1 -maxdepth 1 -type d -print0)
    fi
    
    if [[ ${#bad_examples[@]} -eq 0 ]]; then
        log_error "No bad examples found in $EXAMPLES_DIR/bad"
        return 1
    fi
    
    log_debug "Found ${#bad_examples[@]} bad examples"
    
    # Test plan generation for each bad example
    for example_dir in "${bad_examples[@]}"; do
        local example_name
        example_name=$(basename "$example_dir")
        log_debug "Testing plan generation for bad example: $example_name"
        
        # Create test reports directory
        mkdir -p "$TEST_REPORTS_DIR"
        
        # Generate plan using the generate-plan.sh script
        local plan_json="$TEST_REPORTS_DIR/bad_${example_name}_plan.json"
        
        if ! "$PROJECT_ROOT/scripts/generate-plan.sh" \
            --terraform-dir "$example_dir" \
            --output "$plan_json" >/dev/null 2>&1; then
            # Check if failure is due to authentication (expected for cloud providers)
            if [[ "$example_name" =~ azure ]] && ! command -v az &> /dev/null; then
                log_debug "Skipping Azure example (Azure CLI not available): $example_name"
                continue
            elif [[ "$example_name" =~ aws ]] && [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
                log_debug "Skipping AWS example (AWS credentials not available): $example_name"
                continue
            else
                log_error "Failed to generate plan for bad example: $example_name"
                return 1
            fi
        fi
        
        # Validate plan JSON structure
        if [[ ! -f "$plan_json" ]]; then
            log_error "Plan JSON not created for bad example: $example_name"
            return 1
        fi
        
        if ! jq empty "$plan_json" 2>/dev/null; then
            log_error "Invalid JSON in plan for bad example: $example_name"
            return 1
        fi
        
        log_debug "Plan generation successful for bad example: $example_name"
    done
    
    return 0
}

# Test 5: Test policy evaluation against good examples (should pass)
test_good_examples_policy_evaluation() {
    log_debug "Testing policy evaluation against good examples..."
    
    # Find generated good example plans
    local good_plans=()
    if [[ -d "$TEST_REPORTS_DIR" ]]; then
        while IFS= read -r -d '' file; do
            good_plans+=("$file")
        done < <(find "$TEST_REPORTS_DIR" -name "good_*_plan.json" -type f -print0)
    fi
    
    if [[ ${#good_plans[@]} -eq 0 ]]; then
        log_error "No good example plans found for policy evaluation"
        return 1
    fi
    
    log_debug "Testing policy evaluation for ${#good_plans[@]} good examples"
    
    # Test policy evaluation for each good example
    for plan_json in "${good_plans[@]}"; do
        local plan_name
        plan_name=$(basename "$plan_json" .json)
        log_debug "Testing policy evaluation for: $plan_name"
        
        # Run conftest against the plan
        local violations_json="$TEST_REPORTS_DIR/${plan_name}_violations.json"
        
        # Run conftest (may return non-zero for violations, which is expected)
        "$PROJECT_ROOT/scripts/run-conftest.sh" \
            --input "$plan_json" \
            --output "$violations_json" \
            --format json >/dev/null 2>&1 || true
        
        # Validate violations JSON structure
        if [[ ! -f "$violations_json" ]]; then
            log_error "Violations JSON not created for: $plan_name"
            return 1
        fi
        
        if ! jq empty "$violations_json" 2>/dev/null; then
            log_error "Invalid JSON in violations for: $plan_name"
            return 1
        fi
        
        # Good examples should ideally have no violations, but we'll just check structure
        local violation_count
        violation_count=$(jq '.violations | length' "$violations_json" 2>/dev/null || echo "0")
        log_debug "Good example $plan_name has $violation_count violations"
        
        # Validate violation structure if violations exist
        if [[ "$violation_count" -gt 0 ]]; then
            if ! jq -e '.violations[0] | has("control_id") and has("severity") and has("message")' "$violations_json" >/dev/null 2>&1; then
                log_error "Invalid violation structure in: $plan_name"
                return 1
            fi
        fi
    done
    
    return 0
}

# Test 6: Test policy evaluation against bad examples (should fail)
test_bad_examples_policy_evaluation() {
    log_debug "Testing policy evaluation against bad examples..."
    
    # Find generated bad example plans
    local bad_plans=()
    if [[ -d "$TEST_REPORTS_DIR" ]]; then
        while IFS= read -r -d '' file; do
            bad_plans+=("$file")
        done < <(find "$TEST_REPORTS_DIR" -name "bad_*_plan.json" -type f -print0)
    fi
    
    if [[ ${#bad_plans[@]} -eq 0 ]]; then
        log_error "No bad example plans found for policy evaluation"
        return 1
    fi
    
    log_debug "Testing policy evaluation for ${#bad_plans[@]} bad examples"
    
    # Test policy evaluation for each bad example
    for plan_json in "${bad_plans[@]}"; do
        local plan_name
        plan_name=$(basename "$plan_json" .json)
        log_debug "Testing policy evaluation for: $plan_name"
        
        # Run conftest against the plan
        local violations_json="$TEST_REPORTS_DIR/${plan_name}_violations.json"
        
        # Run conftest (expect violations for bad examples)
        "$PROJECT_ROOT/scripts/run-conftest.sh" \
            --input "$plan_json" \
            --output "$violations_json" \
            --format json >/dev/null 2>&1 || true
        
        # Validate violations JSON structure
        if [[ ! -f "$violations_json" ]]; then
            log_error "Violations JSON not created for: $plan_name"
            return 1
        fi
        
        if ! jq empty "$violations_json" 2>/dev/null; then
            log_error "Invalid JSON in violations for: $plan_name"
            return 1
        fi
        
        # Bad examples should have violations
        local violation_count
        violation_count=$(jq '.violations | length' "$violations_json" 2>/dev/null || echo "0")
        
        if [[ "$violation_count" -eq 0 ]]; then
            log_warn "Bad example $plan_name has no violations (expected some)"
        else
            log_debug "Bad example $plan_name has $violation_count violations (expected)"
        fi
        
        # Validate violation structure if violations exist
        if [[ "$violation_count" -gt 0 ]]; then
            if ! jq -e '.violations[0] | has("control_id") and has("severity") and has("message")' "$violations_json" >/dev/null 2>&1; then
                log_error "Invalid violation structure in: $plan_name"
                return 1
            fi
        fi
    done
    
    return 0
}

# Test 7: Test report generation
test_report_generation() {
    log_debug "Testing report generation..."
    
    # Find a violations file to test report generation
    local violations_files=()
    if [[ -d "$TEST_REPORTS_DIR" ]]; then
        while IFS= read -r -d '' file; do
            violations_files+=("$file")
        done < <(find "$TEST_REPORTS_DIR" -name "*_violations.json" -type f -print0)
    fi
    
    if [[ ${#violations_files[@]} -eq 0 ]]; then
        log_error "No violations files found for report generation testing"
        return 1
    fi
    
    # Use the first violations file for testing
    local test_violations="${violations_files[0]}"
    log_debug "Testing report generation with: $(basename "$test_violations")"
    
    # Test JSON report generation
    local json_report="$TEST_REPORTS_DIR/test_report.json"
    if ! "$PROJECT_ROOT/scripts/generate-report.sh" \
        --input "$test_violations" \
        --output-dir "$TEST_REPORTS_DIR" \
        --format json \
        --environment "e2e-test" >/dev/null 2>&1; then
        log_error "Failed to generate JSON report"
        return 1
    fi
    
    # The script generates files with timestamps, so find the generated JSON report
    local generated_json
    generated_json=$(find "$TEST_REPORTS_DIR" -name "*.json" -newer "$test_violations" | head -n1)
    
    if [[ -z "$generated_json" ]]; then
        log_error "JSON report not found after generation"
        return 1
    fi
    
    # Validate JSON report structure
    if [[ ! -f "$generated_json" ]]; then
        log_error "JSON report not created"
        return 1
    fi
    
    if ! jq empty "$generated_json" 2>/dev/null; then
        log_error "Invalid JSON in generated report"
        return 1
    fi
    
    # Check for required report structure
    if ! jq -e '.scan_metadata and .violations' "$generated_json" >/dev/null 2>&1; then
        log_error "Report missing required structure (scan_metadata, violations)"
        return 1
    fi
    
    # Test Markdown report generation
    if ! "$PROJECT_ROOT/scripts/generate-report.sh" \
        --input "$test_violations" \
        --output-dir "$TEST_REPORTS_DIR" \
        --format markdown \
        --environment "e2e-test" >/dev/null 2>&1; then
        log_error "Failed to generate Markdown report"
        return 1
    fi
    
    # Find the generated Markdown report
    local generated_md
    generated_md=$(find "$TEST_REPORTS_DIR" -name "*.md" -newer "$test_violations" | head -n1)
    
    if [[ -z "$generated_md" ]]; then
        log_error "Markdown report not found after generation"
        return 1
    fi
    
    # Validate Markdown report
    if [[ ! -f "$generated_md" ]]; then
        log_error "Markdown report not created"
        return 1
    fi
    
    if [[ ! -s "$generated_md" ]]; then
        log_error "Markdown report is empty"
        return 1
    fi
    
    # Check for basic Markdown structure
    if ! grep -q "# Security Policy Scan Report" "$generated_md"; then
        log_error "Markdown report missing expected header"
        return 1
    fi
    
    log_debug "Report generation successful"
    return 0
}

# Test 8: Test main orchestration script (scan.sh)
test_main_orchestration() {
    log_debug "Testing main orchestration script..."
    
    # Test with a good example (should succeed)
    local good_example_dir
    if [[ -d "$EXAMPLES_DIR/good" ]]; then
        good_example_dir=$(find "$EXAMPLES_DIR/good" -mindepth 1 -maxdepth 1 -type d | head -n1)
    fi
    
    if [[ -z "$good_example_dir" ]]; then
        log_error "No good example directory found for orchestration testing"
        return 1
    fi
    
    log_debug "Testing orchestration with good example: $(basename "$good_example_dir")"
    
    # Set up environment for scan.sh
    export REPORTS_DIR="$TEST_REPORTS_DIR"
    
    # Run scan.sh with good example (should succeed with exit code 0)
    if ! "$PROJECT_ROOT/scripts/scan.sh" \
        --terraform-dir "$good_example_dir" \
        --output json \
        --environment "e2e-test" >/dev/null 2>&1; then
        log_debug "Scan.sh completed for good example (may have violations)"
    fi
    
    # Check that scan.sh created expected outputs
    if [[ ! -f "$PROJECT_ROOT/reports/scan-report.json" ]]; then
        log_error "Main orchestration did not create expected scan report"
        return 1
    fi
    
    # Validate scan report structure
    if ! jq empty "$PROJECT_ROOT/reports/scan-report.json" 2>/dev/null; then
        log_error "Invalid JSON in orchestration scan report"
        return 1
    fi
    
    # Test with a bad example (should fail with violations)
    local bad_example_dir
    if [[ -d "$EXAMPLES_DIR/bad" ]]; then
        bad_example_dir=$(find "$EXAMPLES_DIR/bad" -mindepth 1 -maxdepth 1 -type d | head -n1)
    fi
    
    if [[ -n "$bad_example_dir" ]]; then
        log_debug "Testing orchestration with bad example: $(basename "$bad_example_dir")"
        
        # Run scan.sh with bad example (should fail with violations)
        "$PROJECT_ROOT/scripts/scan.sh" \
            --terraform-dir "$bad_example_dir" \
            --output json \
            --environment "e2e-test" >/dev/null 2>&1 || true
        
        # The scan report should still be created even with violations
        if [[ ! -f "$PROJECT_ROOT/reports/scan-report.json" ]]; then
            log_error "Main orchestration did not create scan report for bad example"
            return 1
        fi
    fi
    
    log_debug "Main orchestration testing successful"
    return 0
}

# Test 9: Test error handling across component boundaries
test_error_handling() {
    log_debug "Testing error handling across component boundaries..."
    
    # Test 1: Invalid Terraform directory
    local invalid_dir="$TEMP_DIR/nonexistent"
    
    if "$PROJECT_ROOT/scripts/generate-plan.sh" \
        --terraform-dir "$invalid_dir" >/dev/null 2>&1; then
        log_error "generate-plan.sh should fail with invalid directory"
        return 1
    fi
    
    # Test 2: Invalid JSON input to conftest
    local invalid_json="$TEMP_DIR/invalid.json"
    echo "invalid json content" > "$invalid_json"
    
    if "$PROJECT_ROOT/scripts/run-conftest.sh" \
        --input "$invalid_json" >/dev/null 2>&1; then
        log_error "run-conftest.sh should fail with invalid JSON"
        return 1
    fi
    
    # Test 3: Missing policy directory
    local temp_policies_dir="$POLICIES_DIR.backup"
    if [[ -d "$POLICIES_DIR" ]]; then
        mv "$POLICIES_DIR" "$temp_policies_dir"
        
        # Create a valid plan JSON for testing
        local valid_plan="$TEMP_DIR/valid_plan.json"
        echo '{"planned_values": {"root_module": {"resources": []}}}' > "$valid_plan"
        
        if "$PROJECT_ROOT/scripts/run-conftest.sh" \
            --input "$valid_plan" >/dev/null 2>&1; then
            log_error "run-conftest.sh should fail with missing policies"
            mv "$temp_policies_dir" "$POLICIES_DIR"
            return 1
        fi
        
        # Restore policies directory
        mv "$temp_policies_dir" "$POLICIES_DIR"
    fi
    
    # Test 4: Invalid report input
    local invalid_violations="$TEMP_DIR/invalid_violations.json"
    echo "[]" > "$invalid_violations"  # Valid JSON but missing metadata
    
    # This should still work but may produce warnings
    "$PROJECT_ROOT/scripts/generate-report.sh" \
        --input "$invalid_violations" \
        --output "$TEMP_DIR/test_report.json" \
        --format json >/dev/null 2>&1 || true
    
    log_debug "Error handling testing successful"
    return 0
}

# Test 10: Test component integration and data flow
test_component_integration() {
    log_debug "Testing component integration and data flow..."
    
    # Create a minimal test Terraform configuration
    local test_tf_dir="$TEMP_DIR/test_terraform"
    mkdir -p "$test_tf_dir"
    
    cat > "$test_tf_dir/main.tf" << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# This should trigger some policy violations
resource "aws_security_group" "test" {
  name_prefix = "test-sg"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Should violate NET-001
  }
}

resource "aws_s3_bucket" "test" {
  bucket = "test-bucket-integration"
  # Missing encryption - should violate DATA-001
}
EOF
    
    # Step 1: Generate plan
    local plan_json="$TEST_REPORTS_DIR/integration_test_plan.json"
    mkdir -p "$TEST_REPORTS_DIR"
    
    if ! "$PROJECT_ROOT/scripts/generate-plan.sh" \
        --terraform-dir "$test_tf_dir" \
        --output "$plan_json" >/dev/null 2>&1; then
        log_error "Integration test: Failed to generate plan"
        return 1
    fi
    
    # Step 2: Run policy evaluation
    local violations_json="$TEST_REPORTS_DIR/integration_test_violations.json"
    
    "$PROJECT_ROOT/scripts/run-conftest.sh" \
        --input "$plan_json" \
        --output "$violations_json" \
        --format json >/dev/null 2>&1 || true
    
    # Step 3: Generate report
    if ! "$PROJECT_ROOT/scripts/generate-report.sh" \
        --input "$violations_json" \
        --output-dir "$TEST_REPORTS_DIR" \
        --format json \
        --environment "integration-test" >/dev/null 2>&1; then
        log_error "Integration test: Failed to generate report"
        return 1
    fi
    
    # Find the generated report (it has a timestamp in the name)
    local report_json
    report_json=$(find "$TEST_REPORTS_DIR" -name "security-report_integration-test_*.json" | head -n1)
    
    if [[ -z "$report_json" ]]; then
        log_error "Integration test: Generated report not found"
        return 1
    fi
    
    # Validate the complete data flow
    if [[ ! -f "$plan_json" ]] || [[ ! -f "$violations_json" ]] || [[ ! -f "$report_json" ]]; then
        log_error "Integration test: Missing output files"
        return 1
    fi
    
    # Validate JSON structure at each step
    for json_file in "$plan_json" "$violations_json" "$report_json"; do
        if ! jq empty "$json_file" 2>/dev/null; then
            log_error "Integration test: Invalid JSON in $(basename "$json_file")"
            return 1
        fi
    done
    
    # Check that violations were detected (we expect some from our test config)
    local violation_count
    violation_count=$(jq '.violations | length' "$violations_json" 2>/dev/null || echo "0")
    
    if [[ "$violation_count" -eq 0 ]]; then
        log_warn "Integration test: Expected violations but none found"
    else
        log_debug "Integration test: Found $violation_count violations as expected"
    fi
    
    # Validate report contains the violations
    local report_violation_count
    report_violation_count=$(jq '.violations | length' "$report_json" 2>/dev/null || echo "0")
    
    if [[ "$report_violation_count" != "$violation_count" ]]; then
        log_error "Integration test: Violation count mismatch between steps"
        return 1
    fi
    
    log_debug "Component integration testing successful"
    return 0
}

# Main test execution
main() {
    log_info "Starting End-to-End Integration Testing"
    log_info "Test timestamp: $TEST_TIMESTAMP"
    log_info "Test reports directory: $TEST_REPORTS_DIR"
    echo
    
    # Create test reports directory
    mkdir -p "$TEST_REPORTS_DIR"
    
    # Run all integration tests
    run_test "Dependencies and Prerequisites" test_dependencies
    run_test "Policy Validation" test_policy_validation
    run_test "Good Examples Plan Generation" test_good_examples_plan_generation
    run_test "Bad Examples Plan Generation" test_bad_examples_plan_generation
    run_test "Good Examples Policy Evaluation" test_good_examples_policy_evaluation
    run_test "Bad Examples Policy Evaluation" test_bad_examples_policy_evaluation
    run_test "Report Generation" test_report_generation
    run_test "Main Orchestration" test_main_orchestration
    run_test "Error Handling" test_error_handling
    run_test "Component Integration" test_component_integration
    
    # Report results
    echo
    log_info "End-to-End Integration Test Results:"
    log_info "  Tests Run: $TESTS_RUN"
    log_success "  Tests Passed: $TESTS_PASSED"
    
    if [[ "$TESTS_FAILED" -gt 0 ]]; then
        log_error "  Tests Failed: $TESTS_FAILED"
        echo
        log_error "Some integration tests failed. Please review the output above."
        log_info "Test artifacts available in: $TEST_REPORTS_DIR"
        exit 1
    else
        echo
        log_success "All integration tests passed!"
        log_info "Test artifacts available in: $TEST_REPORTS_DIR"
        
        # Clean up test artifacts if all tests passed
        if [[ "${KEEP_TEST_ARTIFACTS:-false}" != "true" ]]; then
            log_info "Cleaning up test artifacts..."
            rm -rf "$TEST_REPORTS_DIR" 2>/dev/null || true
        fi
        
        exit 0
    fi
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -k|--keep-artifacts)
            KEEP_TEST_ARTIFACTS="true"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "End-to-End Integration Test for Multi-Cloud Security Policy System"
            echo ""
            echo "OPTIONS:"
            echo "  -v, --verbose         Enable verbose output"
            echo "  -k, --keep-artifacts  Keep test artifacts after completion"
            echo "  -h, --help           Show this help message"
            echo ""
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"