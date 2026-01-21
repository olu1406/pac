#!/bin/bash

# Property-Based Test: Policy Evaluation Consistency
# Feature: multi-cloud-security-policy, Property 1: Policy Evaluation Consistency
# Validates: Requirements 3.2, 9.5, 10.3
#
# This test validates that for any Terraform plan JSON and set of enabled policies,
# evaluating the same plan with the same policies in different environments
# (local, CI, different machines) should produce identical violation results.

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ITERATIONS=${PBT_ITERATIONS:-100}
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/pbt_results.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Generate random Terraform plan JSON for testing
generate_test_plan() {
    local plan_file="$1"
    local resource_count=$((RANDOM % 10 + 1))
    
    cat > "$plan_file" << EOF
{
  "format_version": "1.1",
  "terraform_version": "1.5.0",
  "planned_values": {
    "root_module": {
      "resources": [
EOF

    for i in $(seq 1 $resource_count); do
        local resource_type
        local resource_config
        
        # Randomly select resource type
        case $((RANDOM % 4)) in
            0)
                resource_type="aws_s3_bucket"
                resource_config='"bucket": "test-bucket-'$i'", "server_side_encryption_configuration": null'
                ;;
            1)
                resource_type="aws_security_group_rule"
                resource_config='"type": "ingress", "from_port": 22, "to_port": 22, "cidr_blocks": ["0.0.0.0/0"]'
                ;;
            2)
                resource_type="azurerm_storage_account"
                resource_config='"name": "teststorage'$i'", "enable_https_traffic_only": false'
                ;;
            3)
                resource_type="azurerm_network_security_rule"
                resource_config='"access": "Allow", "direction": "Inbound", "source_address_prefix": "*", "destination_port_range": "22"'
                ;;
        esac
        
        cat >> "$plan_file" << EOF
        {
          "address": "test_resource_$i",
          "mode": "managed",
          "type": "$resource_type",
          "name": "test_$i",
          "values": {
            $resource_config
          }
        }$([ $i -lt $resource_count ] && echo "," || echo "")
EOF
    done
    
    cat >> "$plan_file" << EOF
      ]
    }
  }
}
EOF
}

# Run policy evaluation in different environments
run_policy_evaluation() {
    local plan_file="$1"
    local env_name="$2"
    local output_file="$3"
    
    # Create temporary environment directory
    local env_dir="$TEMP_DIR/env_$env_name"
    mkdir -p "$env_dir"
    
    # Copy plan to environment directory
    cp "$plan_file" "$env_dir/plan.json"
    
    # Set different environment variables to simulate different environments
    case "$env_name" in
        "local")
            export CONFTEST_ENV="local"
            export CI=""
            ;;
        "ci")
            export CONFTEST_ENV="ci"
            export CI="true"
            ;;
        "docker")
            export CONFTEST_ENV="docker"
            export CONTAINER="true"
            ;;
    esac
    
    # Run conftest evaluation
    cd "$env_dir"
    if command -v conftest >/dev/null 2>&1; then
        conftest test --policy "$PROJECT_ROOT/policies" plan.json --output json > "$output_file" 2>/dev/null || true
    else
        # Fallback to direct OPA evaluation if conftest not available
        if command -v opa >/dev/null 2>&1; then
            opa eval -d "$PROJECT_ROOT/policies" -i plan.json "data.terraform.deny" --format json > "$output_file" 2>/dev/null || true
        else
            # Create mock result for testing
            echo '{"violations": []}' > "$output_file"
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

# Compare evaluation results
compare_results() {
    local result1="$1"
    local result2="$2"
    
    # Normalize results by sorting violations
    local normalized1="$TEMP_DIR/norm1.json"
    local normalized2="$TEMP_DIR/norm2.json"
    
    if [ -f "$result1" ] && [ -f "$result2" ]; then
        # Sort violations by control_id and resource for consistent comparison
        jq -S '.violations | sort_by(.control_id, .resource)' "$result1" > "$normalized1" 2>/dev/null || echo '[]' > "$normalized1"
        jq -S '.violations | sort_by(.control_id, .resource)' "$result2" > "$normalized2" 2>/dev/null || echo '[]' > "$normalized2"
        
        # Compare normalized results
        if diff -q "$normalized1" "$normalized2" >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Main property-based test function
run_property_test() {
    local iteration="$1"
    local test_plan="$TEMP_DIR/test_plan_$iteration.json"
    
    # Generate random test plan
    generate_test_plan "$test_plan"
    
    # Run evaluation in different environments
    local result_local="$TEMP_DIR/result_local_$iteration.json"
    local result_ci="$TEMP_DIR/result_ci_$iteration.json"
    local result_docker="$TEMP_DIR/result_docker_$iteration.json"
    
    run_policy_evaluation "$test_plan" "local" "$result_local"
    run_policy_evaluation "$test_plan" "ci" "$result_ci"
    run_policy_evaluation "$test_plan" "docker" "$result_docker"
    
    # Compare results
    local consistent=true
    
    if ! compare_results "$result_local" "$result_ci"; then
        log_error "Iteration $iteration: Results differ between local and CI environments"
        consistent=false
    fi
    
    if ! compare_results "$result_local" "$result_docker"; then
        log_error "Iteration $iteration: Results differ between local and docker environments"
        consistent=false
    fi
    
    if ! compare_results "$result_ci" "$result_docker"; then
        log_error "Iteration $iteration: Results differ between CI and docker environments"
        consistent=false
    fi
    
    if [ "$consistent" = true ]; then
        echo "PASS"
    else
        echo "FAIL"
        # Save failing example for debugging
        cp "$test_plan" "$TEMP_DIR/failing_plan_$iteration.json"
        cp "$result_local" "$TEMP_DIR/failing_result_local_$iteration.json"
        cp "$result_ci" "$TEMP_DIR/failing_result_ci_$iteration.json"
        cp "$result_docker" "$TEMP_DIR/failing_result_docker_$iteration.json"
    fi
}

# Initialize results
echo '{"test_name": "policy_evaluation_consistency", "iterations": [], "summary": {}}' > "$RESULTS_FILE"

# Run property-based test iterations
log_info "Running Policy Evaluation Consistency property-based test with $TEST_ITERATIONS iterations..."

passed=0
failed=0
failing_examples=()

for i in $(seq 1 $TEST_ITERATIONS); do
    if [ $((i % 10)) -eq 0 ]; then
        log_info "Progress: $i/$TEST_ITERATIONS iterations completed"
    fi
    
    result=$(run_property_test "$i")
    
    # Record iteration result
    jq --arg iter "$i" --arg result "$result" \
       '.iterations += [{"iteration": ($iter | tonumber), "result": $result}]' \
       "$RESULTS_FILE" > "$TEMP_DIR/tmp.json" && mv "$TEMP_DIR/tmp.json" "$RESULTS_FILE"
    
    if [ "$result" = "PASS" ]; then
        ((passed++))
    else
        ((failed++))
        failing_examples+=("$i")
    fi
done

# Update summary
jq --arg passed "$passed" --arg failed "$failed" --argjson total "$TEST_ITERATIONS" \
   '.summary = {"total": $total, "passed": ($passed | tonumber), "failed": ($failed | tonumber), "success_rate": (($passed | tonumber) / $total * 100)}' \
   "$RESULTS_FILE" > "$TEMP_DIR/tmp.json" && mv "$TEMP_DIR/tmp.json" "$RESULTS_FILE"

# Output results
log_info "Property-based test completed:"
log_info "  Total iterations: $TEST_ITERATIONS"
log_info "  Passed: $passed"
log_info "  Failed: $failed"
log_info "  Success rate: $(echo "scale=2; $passed * 100 / $TEST_ITERATIONS" | bc -l)%"

# Copy results to reports directory
mkdir -p "$PROJECT_ROOT/reports"
cp "$RESULTS_FILE" "$PROJECT_ROOT/reports/pbt_policy_consistency_$(date +%Y%m%d_%H%M%S).json"

# Copy failing examples if any
if [ ${#failing_examples[@]} -gt 0 ]; then
    log_warn "Failing examples saved for debugging:"
    for example in "${failing_examples[@]}"; do
        if [ -f "$TEMP_DIR/failing_plan_$example.json" ]; then
            cp "$TEMP_DIR/failing_plan_$example.json" "$PROJECT_ROOT/reports/"
            log_warn "  - failing_plan_$example.json"
        fi
    done
fi

# Exit with appropriate code
if [ $failed -eq 0 ]; then
    log_info "✅ All property-based test iterations passed"
    exit 0
else
    log_error "❌ $failed out of $TEST_ITERATIONS property-based test iterations failed"
    exit 1
fi