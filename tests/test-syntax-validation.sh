#!/bin/bash

# Property-Based Test: Syntax Error Reporting
# Feature: multi-cloud-security-policy, Property 15: Syntax Error Reporting
# Validates: Requirements 4.6, 10.4
#
# This test validates that for any policy file with syntax errors,
# the system should provide clear error messages indicating the specific
# location and nature of the syntax issue.

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_ITERATIONS=${PBT_ITERATIONS:-50}
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

# Common syntax error patterns to inject
SYNTAX_ERRORS=(
    "missing_brace:}:{"
    "missing_bracket:]:["
    "missing_paren:):("
    "invalid_operator:==:="
    "missing_quote:\":"
    "invalid_keyword:denny:deny"
    "missing_semicolon::;"
    "invalid_variable:\$invalid:\$var"
    "malformed_string:\"unclosed:\"closed\""
    "invalid_comment:/* unclosed:/* closed */"
)

# Generate a valid Rego policy template
generate_valid_policy() {
    local policy_file="$1"
    
    cat > "$policy_file" << 'EOF'
package terraform.security.test

import rego.v1

# Test control for syntax validation
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not resource.values.server_side_encryption_configuration
    
    msg := {
        "control_id": "TEST-001",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "S3 bucket must have encryption enabled",
        "remediation": "Add server_side_encryption_configuration to the bucket"
    }
}

# Another test rule
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    resource.values.type == "ingress"
    resource.values.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := {
        "control_id": "TEST-002",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Security group allows access from anywhere",
        "remediation": "Restrict CIDR blocks to specific IP ranges"
    }
}
EOF
}

# Inject syntax error into policy
inject_syntax_error() {
    local policy_file="$1"
    local error_type="$2"
    local corrupted_file="$3"
    
    # Copy original file
    cp "$policy_file" "$corrupted_file"
    
    # Parse error type
    local error_name=$(echo "$error_type" | cut -d: -f1)
    local search_pattern=$(echo "$error_type" | cut -d: -f2)
    local replacement=$(echo "$error_type" | cut -d: -f3)
    
    case "$error_name" in
        "missing_brace")
            # Remove a random closing brace
            sed -i 's/}//' "$corrupted_file"
            ;;
        "missing_bracket")
            # Remove a random closing bracket
            sed -i 's/\]//' "$corrupted_file"
            ;;
        "missing_paren")
            # Remove a random closing parenthesis
            sed -i 's/)//' "$corrupted_file"
            ;;
        "invalid_operator")
            # Replace = with ==
            sed -i 's/ = / == /' "$corrupted_file"
            ;;
        "missing_quote")
            # Remove a quote from a string
            sed -i 's/"HIGH/HIGH/' "$corrupted_file"
            ;;
        "invalid_keyword")
            # Replace deny with denny
            sed -i 's/deny /denny /' "$corrupted_file"
            ;;
        "missing_semicolon")
            # This doesn't apply to Rego, so add invalid semicolon
            sed -i 's/}/};/' "$corrupted_file"
            ;;
        "invalid_variable")
            # Add invalid variable syntax
            sed -i 's/resource/\$invalid_var/' "$corrupted_file"
            ;;
        "malformed_string")
            # Create unclosed string
            sed -i 's/"HIGH"/"HIGH/' "$corrupted_file"
            ;;
        "invalid_comment")
            # Add unclosed comment
            sed -i '1i/* unclosed comment' "$corrupted_file"
            ;;
    esac
}

# Validate policy syntax using available tools
validate_policy_syntax() {
    local policy_file="$1"
    local output_file="$2"
    
    # Try different validation methods
    local validation_output=""
    local validation_result=0
    
    # Method 1: Use OPA fmt for syntax checking
    if command -v opa >/dev/null 2>&1; then
        validation_output=$(opa fmt "$policy_file" 2>&1) || validation_result=$?
        if [ $validation_result -ne 0 ]; then
            echo "$validation_output" > "$output_file"
            return $validation_result
        fi
    fi
    
    # Method 2: Use OPA test for syntax validation
    if command -v opa >/dev/null 2>&1; then
        validation_output=$(opa test "$policy_file" 2>&1) || validation_result=$?
        if [ $validation_result -ne 0 ]; then
            echo "$validation_output" > "$output_file"
            return $validation_result
        fi
    fi
    
    # Method 3: Use conftest verify
    if command -v conftest >/dev/null 2>&1; then
        validation_output=$(conftest verify --policy "$policy_file" 2>&1) || validation_result=$?
        if [ $validation_result -ne 0 ]; then
            echo "$validation_output" > "$output_file"
            return $validation_result
        fi
    fi
    
    # Method 4: Use validate-policies.sh script if available
    if [ -x "$PROJECT_ROOT/scripts/validate-policies.sh" ]; then
        local temp_policy_dir="$TEMP_DIR/policy_validation"
        mkdir -p "$temp_policy_dir"
        cp "$policy_file" "$temp_policy_dir/"
        
        cd "$temp_policy_dir"
        validation_output=$("$PROJECT_ROOT/scripts/validate-policies.sh" 2>&1) || validation_result=$?
        cd "$PROJECT_ROOT"
        
        if [ $validation_result -ne 0 ]; then
            echo "$validation_output" > "$output_file"
            return $validation_result
        fi
    fi
    
    # If no errors found
    echo "No syntax errors detected" > "$output_file"
    return 0
}

# Analyze error message quality
analyze_error_message() {
    local error_output="$1"
    local expected_error_type="$2"
    local quality_score=0
    
    if [ ! -f "$error_output" ]; then
        echo "0"
        return
    fi
    
    local error_text=$(cat "$error_output")
    
    # Check if error message contains useful information
    # 1. Contains line number or position information
    if echo "$error_text" | grep -qE '[Ll]ine [0-9]+|[Pp]osition [0-9]+|:[0-9]+:'; then
        ((quality_score += 25))
    fi
    
    # 2. Contains specific error description
    if echo "$error_text" | grep -qiE 'syntax|parse|invalid|unexpected|missing|error'; then
        ((quality_score += 25))
    fi
    
    # 3. Contains file name or path
    if echo "$error_text" | grep -qE '\.rego|policy|file'; then
        ((quality_score += 20))
    fi
    
    # 4. Error message is not empty and not generic
    if [ -n "$error_text" ] && ! echo "$error_text" | grep -qE '^(OK|Success|No errors)$'; then
        ((quality_score += 15))
    fi
    
    # 5. Contains context about what was expected
    if echo "$error_text" | grep -qiE 'expected|should|must|required'; then
        ((quality_score += 15))
    fi
    
    echo "$quality_score"
}

# Test syntax error reporting for a single iteration
test_syntax_error_reporting() {
    local iteration="$1"
    local valid_policy="$TEMP_DIR/valid_policy_$iteration.rego"
    local corrupted_policy="$TEMP_DIR/corrupted_policy_$iteration.rego"
    local error_output="$TEMP_DIR/error_output_$iteration.txt"
    
    # Generate valid policy
    generate_valid_policy "$valid_policy"
    
    # Select random error type
    local error_type="${SYNTAX_ERRORS[$((RANDOM % ${#SYNTAX_ERRORS[@]}))]}"
    
    # Inject syntax error
    inject_syntax_error "$valid_policy" "$error_type" "$corrupted_policy"
    
    # Validate corrupted policy (should fail)
    local validation_result=0
    validate_policy_syntax "$corrupted_policy" "$error_output" || validation_result=$?
    
    # Analyze error message quality
    local error_name=$(echo "$error_type" | cut -d: -f1)
    local quality_score=$(analyze_error_message "$error_output" "$error_name")
    
    # Test passes if:
    # 1. Validation failed (detected the syntax error)
    # 2. Error message quality is reasonable (>= 50 points)
    if [ $validation_result -ne 0 ] && [ "$quality_score" -ge 50 ]; then
        echo "PASS"
    else
        echo "FAIL"
        # Save failing example
        cp "$valid_policy" "$TEMP_DIR/failing_valid_$iteration.rego"
        cp "$corrupted_policy" "$TEMP_DIR/failing_corrupted_$iteration.rego"
        cp "$error_output" "$TEMP_DIR/failing_error_$iteration.txt"
        echo "Error type: $error_type, Quality score: $quality_score, Validation result: $validation_result" > "$TEMP_DIR/failing_details_$iteration.txt"
    fi
}

# Initialize results
echo '{"test_name": "syntax_error_reporting", "iterations": [], "summary": {}}' > "$RESULTS_FILE"

# Run property-based test iterations
log_info "Running Syntax Error Reporting property-based test with $TEST_ITERATIONS iterations..."

passed=0
failed=0
failing_examples=()

for i in $(seq 1 $TEST_ITERATIONS); do
    if [ $((i % 10)) -eq 0 ]; then
        log_info "Progress: $i/$TEST_ITERATIONS iterations completed"
    fi
    
    result=$(test_syntax_error_reporting "$i")
    
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
cp "$RESULTS_FILE" "$PROJECT_ROOT/reports/pbt_syntax_validation_$(date +%Y%m%d_%H%M%S).json"

# Copy failing examples if any
if [ ${#failing_examples[@]} -gt 0 ]; then
    log_warn "Failing examples saved for debugging:"
    for example in "${failing_examples[@]}"; do
        for file in "$TEMP_DIR"/failing_*"$example".*; do
            if [ -f "$file" ]; then
                cp "$file" "$PROJECT_ROOT/reports/"
                log_warn "  - $(basename "$file")"
            fi
        done
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