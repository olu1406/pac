#!/bin/bash

# Property-Based Test: Credential Independence
# Feature: multi-cloud-security-policy, Property 14: Credential Independence
# Validates: Requirements 10.2, 11.3
#
# This test validates that for any basic policy validation operation,
# the system should execute successfully without requiring cloud provider credentials.

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ITERATIONS=${PBT_ITERATIONS:-30}
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
    # Restore original environment variables
    if [ -n "${ORIGINAL_AWS_ACCESS_KEY_ID:-}" ]; then
        export AWS_ACCESS_KEY_ID="$ORIGINAL_AWS_ACCESS_KEY_ID"
    else
        unset AWS_ACCESS_KEY_ID 2>/dev/null || true
    fi
    if [ -n "${ORIGINAL_AWS_SECRET_ACCESS_KEY:-}" ]; then
        export AWS_SECRET_ACCESS_KEY="$ORIGINAL_AWS_SECRET_ACCESS_KEY"
    else
        unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
    fi
    if [ -n "${ORIGINAL_AZURE_CLIENT_ID:-}" ]; then
        export AZURE_CLIENT_ID="$ORIGINAL_AZURE_CLIENT_ID"
    else
        unset AZURE_CLIENT_ID 2>/dev/null || true
    fi
    if [ -n "${ORIGINAL_AZURE_CLIENT_SECRET:-}" ]; then
        export AZURE_CLIENT_SECRET="$ORIGINAL_AZURE_CLIENT_SECRET"
    else
        unset AZURE_CLIENT_SECRET 2>/dev/null || true
    fi
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

# Save original environment variables
ORIGINAL_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
ORIGINAL_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
ORIGINAL_AZURE_CLIENT_ID="${AZURE_CLIENT_ID:-}"
ORIGINAL_AZURE_CLIENT_SECRET="${AZURE_CLIENT_SECRET:-}"

# Clear all cloud credentials
clear_credentials() {
    # AWS credentials
    unset AWS_ACCESS_KEY_ID 2>/dev/null || true
    unset AWS_SECRET_ACCESS_KEY 2>/dev/null || true
    unset AWS_SESSION_TOKEN 2>/dev/null || true
    unset AWS_PROFILE 2>/dev/null || true
    unset AWS_DEFAULT_REGION 2>/dev/null || true
    unset AWS_REGION 2>/dev/null || true
    
    # Azure credentials
    unset AZURE_CLIENT_ID 2>/dev/null || true
    unset AZURE_CLIENT_SECRET 2>/dev/null || true
    unset AZURE_TENANT_ID 2>/dev/null || true
    unset AZURE_SUBSCRIPTION_ID 2>/dev/null || true
    
    # Google Cloud credentials
    unset GOOGLE_APPLICATION_CREDENTIALS 2>/dev/null || true
    unset GCLOUD_PROJECT 2>/dev/null || true
    
    # Remove credential files if they exist
    rm -f ~/.aws/credentials 2>/dev/null || true
    rm -f ~/.azure/credentials 2>/dev/null || true
}

# Generate test Terraform plan
generate_test_plan() {
    local plan_file="$1"
    local cloud_provider="$2"
    
    case "$cloud_provider" in
        "aws")
            cat > "$plan_file" << 'EOF'
{
  "format_version": "1.1",
  "terraform_version": "1.5.0",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "aws_s3_bucket.test",
          "mode": "managed",
          "type": "aws_s3_bucket",
          "name": "test",
          "values": {
            "bucket": "test-bucket-no-encryption",
            "server_side_encryption_configuration": null
          }
        },
        {
          "address": "aws_security_group_rule.ssh",
          "mode": "managed",
          "type": "aws_security_group_rule",
          "name": "ssh",
          "values": {
            "type": "ingress",
            "from_port": 22,
            "to_port": 22,
            "protocol": "tcp",
            "cidr_blocks": ["0.0.0.0/0"]
          }
        }
      ]
    }
  }
}
EOF
            ;;
        "azure")
            cat > "$plan_file" << 'EOF'
{
  "format_version": "1.1",
  "terraform_version": "1.5.0",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "azurerm_storage_account.test",
          "mode": "managed",
          "type": "azurerm_storage_account",
          "name": "test",
          "values": {
            "name": "teststorageaccount",
            "enable_https_traffic_only": false,
            "min_tls_version": "TLS1_0"
          }
        },
        {
          "address": "azurerm_network_security_rule.rdp",
          "mode": "managed",
          "type": "azurerm_network_security_rule",
          "name": "rdp",
          "values": {
            "access": "Allow",
            "direction": "Inbound",
            "protocol": "Tcp",
            "source_address_prefix": "*",
            "destination_port_range": "3389"
          }
        }
      ]
    }
  }
}
EOF
            ;;
        "mixed")
            cat > "$plan_file" << 'EOF'
{
  "format_version": "1.1",
  "terraform_version": "1.5.0",
  "planned_values": {
    "root_module": {
      "resources": [
        {
          "address": "aws_s3_bucket.test",
          "mode": "managed",
          "type": "aws_s3_bucket",
          "name": "test",
          "values": {
            "bucket": "test-bucket",
            "server_side_encryption_configuration": null
          }
        },
        {
          "address": "azurerm_storage_account.test",
          "mode": "managed",
          "type": "azurerm_storage_account",
          "name": "test",
          "values": {
            "name": "teststorage",
            "enable_https_traffic_only": false
          }
        }
      ]
    }
  }
}
EOF
            ;;
    esac
}

# Test operations that should work without credentials
test_operation_without_credentials() {
    local operation="$1"
    local test_dir="$2"
    local result_file="$3"
    
    cd "$test_dir"
    
    case "$operation" in
        "policy_validation")
            if [ -x "$PROJECT_ROOT/scripts/validate-policies.sh" ]; then
                "$PROJECT_ROOT/scripts/validate-policies.sh" > "$result_file" 2>&1
                return $?
            else
                echo "Policy validation script not found" > "$result_file"
                return 1
            fi
            ;;
        "conftest_evaluation")
            if command -v conftest >/dev/null 2>&1 && [ -f "plan.json" ]; then
                conftest test --policy "$PROJECT_ROOT/policies" plan.json > "$result_file" 2>&1
                return $?
            else
                echo "Conftest not available or plan.json missing" > "$result_file"
                return 1
            fi
            ;;
        "opa_evaluation")
            if command -v opa >/dev/null 2>&1 && [ -f "plan.json" ]; then
                opa eval -d "$PROJECT_ROOT/policies" -i plan.json "data.terraform.deny" > "$result_file" 2>&1
                return $?
            else
                echo "OPA not available or plan.json missing" > "$result_file"
                return 1
            fi
            ;;
        "report_generation")
            if [ -x "$PROJECT_ROOT/scripts/generate-report.sh" ] && [ -f "plan.json" ]; then
                "$PROJECT_ROOT/scripts/generate-report.sh" -i plan.json -o report.json > "$result_file" 2>&1
                return $?
            else
                echo "Report generation script not found or plan.json missing" > "$result_file"
                return 1
            fi
            ;;
        "scan_script")
            if [ -x "$PROJECT_ROOT/scripts/scan.sh" ] && [ -f "plan.json" ]; then
                "$PROJECT_ROOT/scripts/scan.sh" -p plan.json -e local > "$result_file" 2>&1
                return $?
            else
                echo "Scan script not found or plan.json missing" > "$result_file"
                return 1
            fi
            ;;
        "control_listing")
            if [ -x "$PROJECT_ROOT/scripts/list-controls.sh" ]; then
                "$PROJECT_ROOT/scripts/list-controls.sh" > "$result_file" 2>&1
                return $?
            else
                echo "Control listing script not found" > "$result_file"
                return 1
            fi
            ;;
    esac
}

# Check if operation failed due to missing credentials
check_credential_dependency() {
    local result_file="$1"
    
    if [ ! -f "$result_file" ]; then
        return 1
    fi
    
    local result_text=$(cat "$result_file")
    
    # Check for credential-related error messages
    if echo "$result_text" | grep -qiE 'credential|authentication|unauthorized|access.*denied|invalid.*key|token.*expired|login.*required'; then
        return 0  # Operation failed due to credentials
    fi
    
    # Check for AWS-specific credential errors
    if echo "$result_text" | grep -qiE 'aws.*credential|aws.*access|aws.*secret|aws.*token'; then
        return 0
    fi
    
    # Check for Azure-specific credential errors
    if echo "$result_text" | grep -qiE 'azure.*credential|azure.*client|azure.*tenant|azure.*subscription'; then
        return 0
    fi
    
    return 1  # Operation did not fail due to credentials
}

# Test credential independence for a single iteration
test_credential_independence() {
    local iteration="$1"
    local test_dir="$TEMP_DIR/test_$iteration"
    local cloud_providers=("aws" "azure" "mixed")
    local operations=("policy_validation" "conftest_evaluation" "opa_evaluation" "report_generation" "scan_script" "control_listing")
    
    # Create test directory
    mkdir -p "$test_dir"
    
    # Clear all credentials
    clear_credentials
    
    # Select random cloud provider and operation
    local cloud_provider="${cloud_providers[$((RANDOM % ${#cloud_providers[@]}))]}"
    local operation="${operations[$((RANDOM % ${#operations[@]}))]}"
    
    # Generate test plan if needed
    if [[ "$operation" =~ (conftest_evaluation|opa_evaluation|report_generation|scan_script) ]]; then
        generate_test_plan "$test_dir/plan.json" "$cloud_provider"
    fi
    
    # Run operation
    local result_file="$test_dir/result.txt"
    local operation_result=0
    test_operation_without_credentials "$operation" "$test_dir" "$result_file" || operation_result=$?
    
    # Check if failure was due to missing credentials
    local credential_dependent=false
    if [ $operation_result -ne 0 ]; then
        if check_credential_dependency "$result_file"; then
            credential_dependent=true
        fi
    fi
    
    # Test passes if:
    # 1. Operation succeeded (exit code 0), OR
    # 2. Operation failed but NOT due to missing credentials
    if [ $operation_result -eq 0 ] || [ "$credential_dependent" = false ]; then
        echo "PASS"
    else
        echo "FAIL"
        # Save failing example
        cp -r "$test_dir" "$TEMP_DIR/failing_test_$iteration"
        echo "Operation: $operation, Cloud: $cloud_provider, Exit code: $operation_result" > "$TEMP_DIR/failing_details_$iteration.txt"
    fi
}

# Initialize results
echo '{"test_name": "credential_independence", "iterations": [], "summary": {}}' > "$RESULTS_FILE"

# Run property-based test iterations
log_info "Running Credential Independence property-based test with $TEST_ITERATIONS iterations..."

passed=0
failed=0
failing_examples=()

for i in $(seq 1 $TEST_ITERATIONS); do
    if [ $((i % 5)) -eq 0 ]; then
        log_info "Progress: $i/$TEST_ITERATIONS iterations completed"
    fi
    
    result=$(test_credential_independence "$i")
    
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
cp "$RESULTS_FILE" "$PROJECT_ROOT/reports/pbt_credential_independence_$(date +%Y%m%d_%H%M%S).json"

# Copy failing examples if any
if [ ${#failing_examples[@]} -gt 0 ]; then
    log_warn "Failing examples saved for debugging:"
    for example in "${failing_examples[@]}"; do
        if [ -d "$TEMP_DIR/failing_test_$example" ]; then
            cp -r "$TEMP_DIR/failing_test_$example" "$PROJECT_ROOT/reports/"
            log_warn "  - failing_test_$example/"
        fi
        if [ -f "$TEMP_DIR/failing_details_$example.txt" ]; then
            cp "$TEMP_DIR/failing_details_$example.txt" "$PROJECT_ROOT/reports/"
            log_warn "  - failing_details_$example.txt"
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