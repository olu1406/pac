#!/bin/bash

# Policy Test Framework Script
# Tests policies against positive/negative test cases with result aggregation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="${POLICIES_DIR:-$PROJECT_ROOT/policies}"
EXAMPLES_DIR="${EXAMPLES_DIR:-$PROJECT_ROOT/examples}"
REPORTS_DIR="${REPORTS_DIR:-$PROJECT_ROOT/reports}"

# Default configuration
TEST_TYPE="${TEST_TYPE:-all}"
POLICY_DIRS="${POLICY_DIRS:-}"
OUTPUT_FILE="${OUTPUT_FILE:-}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
FAIL_FAST="${FAIL_FAST:-false}"
VERBOSE="${VERBOSE:-false}"
PARALLEL="${PARALLEL:-false}"
GENERATE_FIXTURES="${GENERATE_FIXTURES:-false}"

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

Test policies against positive/negative test cases with result aggregation.

OPTIONS:
    -t, --test-type TYPE        Test type: positive, negative, all (default: all)
    -p, --policy-dirs DIRS      Comma-separated policy directories (default: auto-discover)
    -o, --output FILE           Output file for test results (default: auto-generated)
    -f, --format FORMAT         Output format: json, table, junit (default: json)
    -F, --fail-fast             Stop on first test failure (default: false)
    -P, --parallel              Run tests in parallel (default: false)
    -G, --generate-fixtures     Generate missing test fixtures (default: false)
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

TEST TYPES:
    positive                    Test that good examples pass policies (no violations)
    negative                    Test that bad examples trigger expected violations
    all                         Run both positive and negative tests

EXAMPLES:
    $0                                          # Run all tests
    $0 -t positive                             # Run only positive tests
    $0 -t negative -F                          # Run negative tests, stop on first failure
    $0 -p policies/aws -f junit                # Test AWS policies with JUnit output
    $0 -G                                       # Generate missing test fixtures

ENVIRONMENT VARIABLES:
    TEST_TYPE                   Override test type
    POLICY_DIRS                 Override policy directories
    OUTPUT_FILE                 Override output file
    OUTPUT_FORMAT               Override output format
    FAIL_FAST                   Stop on first failure (true/false)
    VERBOSE                     Enable verbose output (true/false)
    PARALLEL                    Run tests in parallel (true/false)
    GENERATE_FIXTURES           Generate missing fixtures (true/false)
    POLICIES_DIR                Override base policies directory
    EXAMPLES_DIR                Override examples directory
    REPORTS_DIR                 Override reports directory

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--test-type)
                TEST_TYPE="$2"
                shift 2
                ;;
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
            -P|--parallel)
                PARALLEL="true"
                shift
                ;;
            -G|--generate-fixtures)
                GENERATE_FIXTURES="true"
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
    
    if ! command -v conftest &> /dev/null; then
        missing_deps+=("conftest")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Installation instructions:"
        for dep in "${missing_deps[@]}"; do
            case $dep in
                conftest)
                    log_info "  Conftest: https://www.conftest.dev/install/"
                    ;;
                jq)
                    log_info "  jq: https://stedolan.github.io/jq/download/"
                    ;;
                terraform)
                    log_info "  Terraform: https://www.terraform.io/downloads.html"
                    ;;
            esac
        done
        exit 1
    fi
    
    log_debug "Dependencies validated successfully"
}

# Validate test type
validate_test_type() {
    case "$TEST_TYPE" in
        positive|negative|all)
            log_debug "Test type validated: $TEST_TYPE"
            ;;
        *)
            log_error "Invalid test type: $TEST_TYPE"
            log_info "Supported types: positive, negative, all"
            exit 1
            ;;
    esac
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
        # Auto-discover policy directories
        if [[ -d "$POLICIES_DIR" ]]; then
            # Find subdirectories with .rego files
            while IFS= read -r -d '' dir; do
                discovered_dirs+=("$dir")
            done < <(find "$POLICIES_DIR" -type f -name "*.rego" -exec dirname {} \; | sort -u | tr '\n' '\0')
        fi
    fi
    
    if [[ ${#discovered_dirs[@]} -eq 0 ]]; then
        log_error "No policy directories found"
        exit 1
    fi
    
    log_info "Found ${#discovered_dirs[@]} policy directories"
    printf '%s\n' "${discovered_dirs[@]}"
}

# Generate Terraform plan JSON from directory
generate_plan_json() {
    local terraform_dir="$1"
    local output_file="$2"
    
    log_debug "Generating Terraform plan for: $terraform_dir"
    
    # Change to terraform directory
    local original_dir
    original_dir=$(pwd)
    cd "$terraform_dir"
    
    # Initialize terraform if needed
    if [[ ! -d ".terraform" ]]; then
        log_debug "Initializing Terraform in $terraform_dir"
        if ! terraform init -no-color >/dev/null 2>&1; then
            log_error "Failed to initialize Terraform in $terraform_dir"
            cd "$original_dir"
            return 1
        fi
    fi
    
    # Generate plan
    local plan_file
    plan_file=$(mktemp)
    
    if ! terraform plan -no-color -out="$plan_file" >/dev/null 2>&1; then
        log_error "Failed to generate Terraform plan in $terraform_dir"
        rm -f "$plan_file"
        cd "$original_dir"
        return 1
    fi
    
    # Convert plan to JSON
    if ! terraform show -json "$plan_file" > "$output_file" 2>/dev/null; then
        log_error "Failed to convert Terraform plan to JSON in $terraform_dir"
        rm -f "$plan_file"
        cd "$original_dir"
        return 1
    fi
    
    # Cleanup
    rm -f "$plan_file"
    cd "$original_dir"
    
    log_debug "Generated plan JSON: $output_file"
    return 0
}

# Run conftest against plan JSON
run_conftest_test() {
    local plan_json="$1"
    local policy_dir="$2"
    local expected_result="$3"  # "pass" or "fail"
    
    log_debug "Running conftest: policy=$policy_dir, expected=$expected_result"
    
    # Run conftest
    local conftest_output conftest_exit_code=0
    conftest_output=$(conftest verify --policy "$policy_dir" --output json "$plan_json" 2>/dev/null) || conftest_exit_code=$?
    
    # Determine actual result
    local actual_result
    if [[ $conftest_exit_code -eq 0 ]]; then
        actual_result="pass"
    else
        actual_result="fail"
    fi
    
    # Check if result matches expectation
    local test_passed=false
    if [[ "$actual_result" == "$expected_result" ]]; then
        test_passed=true
    fi
    
    # Parse violations from conftest output
    local violations="[]"
    if [[ -n "$conftest_output" ]] && echo "$conftest_output" | jq empty 2>/dev/null; then
        violations="$conftest_output"
    fi
    
    # Create test result
    local test_result
    test_result=$(cat << EOF
{
    "test_passed": $test_passed,
    "expected_result": "$expected_result",
    "actual_result": "$actual_result",
    "policy_directory": "$policy_dir",
    "plan_file": "$plan_json",
    "conftest_exit_code": $conftest_exit_code,
    "violations": $violations
}
EOF
)
    
    echo "$test_result"
    
    if $test_passed; then
        return 0
    else
        return 1
    fi
}

# Test single example directory
test_example_directory() {
    local example_dir="$1"
    local test_type="$2"  # "positive" or "negative"
    local policy_dirs=("${@:3}")
    
    log_info "Testing example: $example_dir ($test_type)"
    
    # Generate plan JSON
    local plan_json
    plan_json=$(mktemp --suffix=.json)
    
    if ! generate_plan_json "$example_dir" "$plan_json"; then
        log_error "Failed to generate plan for $example_dir"
        rm -f "$plan_json"
        return 1
    fi
    
    # Test against each policy directory
    local all_results=()
    local failed_tests=0
    
    for policy_dir in "${policy_dirs[@]}"; do
        local expected_result
        if [[ "$test_type" == "positive" ]]; then
            expected_result="pass"
        else
            expected_result="fail"
        fi
        
        local test_result exit_code=0
        test_result=$(run_conftest_test "$plan_json" "$policy_dir" "$expected_result") || exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            ((failed_tests++))
            if [[ "$FAIL_FAST" == "true" ]]; then
                log_error "Test failed for $example_dir against $policy_dir (fail-fast enabled)"
                break
            fi
        fi
        
        # Add metadata to test result
        local enhanced_result
        enhanced_result=$(echo "$test_result" | jq --arg example "$example_dir" --arg type "$test_type" '. + {
            "example_directory": $example,
            "test_type": $type
        }')
        
        all_results+=("$enhanced_result")
    done
    
    # Cleanup
    rm -f "$plan_json"
    
    # Output results
    printf '%s\n' "${all_results[@]}"
    
    return $failed_tests
}

# Discover test examples
discover_test_examples() {
    local test_type="$1"
    local examples=()
    
    case "$test_type" in
        positive)
            if [[ -d "$EXAMPLES_DIR/good" ]]; then
                while IFS= read -r -d '' dir; do
                    examples+=("$dir")
                done < <(find "$EXAMPLES_DIR/good" -mindepth 1 -maxdepth 1 -type d -print0)
            fi
            ;;
        negative)
            if [[ -d "$EXAMPLES_DIR/bad" ]]; then
                while IFS= read -r -d '' dir; do
                    examples+=("$dir")
                done < <(find "$EXAMPLES_DIR/bad" -mindepth 1 -maxdepth 1 -type d -print0)
            fi
            ;;
        all)
            # Recursively call for both types
            local positive_examples negative_examples
            readarray -t positive_examples < <(discover_test_examples "positive")
            readarray -t negative_examples < <(discover_test_examples "negative")
            examples=("${positive_examples[@]}" "${negative_examples[@]}")
            ;;
    esac
    
    printf '%s\n' "${examples[@]}"
}

# Generate basic test fixtures
generate_test_fixtures() {
    log_info "Generating basic test fixtures"
    
    # Create good examples directory
    mkdir -p "$EXAMPLES_DIR/good/aws-basic"
    mkdir -p "$EXAMPLES_DIR/good/azure-basic"
    
    # Create bad examples directory
    mkdir -p "$EXAMPLES_DIR/bad/aws-violations"
    mkdir -p "$EXAMPLES_DIR/bad/azure-violations"
    
    # Generate AWS good example
    cat > "$EXAMPLES_DIR/good/aws-basic/main.tf" << 'EOF'
# Good AWS Example - Should pass all policies
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Secure S3 bucket
resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_bucket_encryption" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "secure_bucket_pab" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Secure IAM role
resource "aws_iam_role" "secure_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "secure_policy" {
  name = "secure-policy"
  role = aws_iam_role.secure_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.secure_bucket.arn}/*"
      }
    ]
  })
}
EOF

    cat > "$EXAMPLES_DIR/good/aws-basic/variables.tf" << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "secure-test-bucket"
}

variable "role_name" {
  description = "IAM role name"
  type        = string
  default     = "secure-test-role"
}
EOF

    cat > "$EXAMPLES_DIR/good/aws-basic/outputs.tf" << 'EOF'
output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.secure_bucket.arn
}

output "role_arn" {
  description = "ARN of the IAM role"
  value       = aws_iam_role.secure_role.arn
}
EOF

    # Generate AWS bad example
    cat > "$EXAMPLES_DIR/bad/aws-violations/main.tf" << 'EOF'
# Bad AWS Example - Should trigger policy violations
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Insecure S3 bucket (no encryption)
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = var.bucket_name
}

# Insecure IAM policy (wildcard permissions)
resource "aws_iam_policy" "insecure_policy" {
  name        = "insecure-policy"
  description = "Insecure policy with wildcard permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      }
    ]
  })
}

# Insecure IAM role (wildcard trust policy)
resource "aws_iam_role" "insecure_role" {
  name = var.role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = "*"
      }
    ]
  })
}

# Insecure security group (SSH from anywhere)
resource "aws_security_group" "insecure_sg" {
  name_prefix = "insecure-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF

    cat > "$EXAMPLES_DIR/bad/aws-violations/variables.tf" << 'EOF'
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
  default     = "insecure-test-bucket"
}

variable "role_name" {
  description = "IAM role name"
  type        = string
  default     = "insecure-test-role"
}
EOF

    # Generate Azure good example
    cat > "$EXAMPLES_DIR/good/azure-basic/main.tf" << 'EOF'
# Good Azure Example - Should pass all policies
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Secure resource group
resource "azurerm_resource_group" "secure_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Secure storage account
resource "azurerm_storage_account" "secure_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.secure_rg.name
  location                 = azurerm_resource_group.secure_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version = "TLS1_2"
  
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

# Secure role assignment
resource "azurerm_role_assignment" "secure_assignment" {
  scope                = azurerm_resource_group.secure_rg.id
  role_definition_name = "Reader"
  principal_id         = var.principal_id
}
EOF

    cat > "$EXAMPLES_DIR/good/azure-basic/variables.tf" << 'EOF'
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "secure-test-rg"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
  default     = "secureteststorage"
}

variable "principal_id" {
  description = "Principal ID for role assignment"
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
EOF

    # Generate Azure bad example
    cat > "$EXAMPLES_DIR/bad/azure-violations/main.tf" << 'EOF'
# Bad Azure Example - Should trigger policy violations
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource group
resource "azurerm_resource_group" "insecure_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Insecure storage account (no encryption, old TLS)
resource "azurerm_storage_account" "insecure_storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.insecure_rg.name
  location                 = azurerm_resource_group.insecure_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  min_tls_version = "TLS1_0"
}

# Insecure role assignment (Owner at subscription level)
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "insecure_assignment" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Owner"
  principal_id         = var.principal_id
}

# Insecure custom role (wildcard permissions)
resource "azurerm_role_definition" "insecure_role" {
  name  = "insecure-custom-role"
  scope = azurerm_resource_group.insecure_rg.id

  permissions {
    actions = ["*"]
  }

  assignable_scopes = [
    azurerm_resource_group.insecure_rg.id
  ]
}
EOF

    cat > "$EXAMPLES_DIR/bad/azure-violations/variables.tf" << 'EOF'
variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "insecure-test-rg"
}

variable "location" {
  description = "Azure location"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "Storage account name"
  type        = string
  default     = "insecureteststorage"
}

variable "principal_id" {
  description = "Principal ID for role assignment"
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}
EOF

    log_success "Generated basic test fixtures in $EXAMPLES_DIR"
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
            OUTPUT_FILE="$REPORTS_DIR/policy_tests_${timestamp}.json"
            ;;
        table)
            OUTPUT_FILE="$REPORTS_DIR/policy_tests_${timestamp}.txt"
            ;;
        junit)
            OUTPUT_FILE="$REPORTS_DIR/policy_tests_${timestamp}.xml"
            ;;
    esac
    
    log_debug "Generated output file: $OUTPUT_FILE"
}

# Format results as table
format_table_output() {
    local json_results="$1"
    local output_file="$2"
    
    {
        echo "Policy Test Results"
        echo "==================="
        echo
        
        # Summary
        local total_tests passed_tests failed_tests
        total_tests=$(echo "$json_results" | jq '.test_results | length')
        passed_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == true)] | length')
        failed_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == false)] | length')
        
        echo "Summary:"
        echo "  Total tests: $total_tests"
        echo "  Passed: $passed_tests"
        echo "  Failed: $failed_tests"
        echo
        
        # Group by test type
        local positive_tests negative_tests
        positive_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_type == "positive")]')
        negative_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_type == "negative")]')
        
        if [[ "$(echo "$positive_tests" | jq 'length')" -gt 0 ]]; then
            echo "Positive Tests (Good Examples):"
            echo "$(printf '%.0s-' {1..40})"
            echo "$positive_tests" | jq -r '.[] | "  \(.example_directory): \(if .test_passed then "PASS" else "FAIL" end) (\(.policy_directory))"'
            echo
        fi
        
        if [[ "$(echo "$negative_tests" | jq 'length')" -gt 0 ]]; then
            echo "Negative Tests (Bad Examples):"
            echo "$(printf '%.0s-' {1..40})"
            echo "$negative_tests" | jq -r '.[] | "  \(.example_directory): \(if .test_passed then "PASS" else "FAIL" end) (\(.policy_directory))"'
            echo
        fi
        
        # Failed tests details
        local failed_test_details
        failed_test_details=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == false)]')
        
        if [[ "$(echo "$failed_test_details" | jq 'length')" -gt 0 ]]; then
            echo "Failed Test Details:"
            echo "$(printf '%.0s-' {1..40})"
            echo "$failed_test_details" | jq -r '.[] | "
Example: \(.example_directory)
Policy: \(.policy_directory)
Expected: \(.expected_result)
Actual: \(.actual_result)
Violations: \(.violations | length)
"'
        fi
        
    } > "$output_file"
}

# Format results as JUnit XML
format_junit_output() {
    local json_results="$1"
    local output_file="$2"
    
    local total_tests passed_tests failed_tests
    total_tests=$(echo "$json_results" | jq '.test_results | length')
    passed_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == true)] | length')
    failed_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == false)] | length')
    
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo "<testsuite name=\"PolicyTests\" tests=\"$total_tests\" failures=\"$failed_tests\" errors=\"0\" time=\"0\">"
        
        echo "$json_results" | jq -r '.test_results[] | 
            "<testcase classname=\"\(.test_type)\" name=\"\(.example_directory)_\(.policy_directory | gsub("/"; "_"))\" time=\"0\">" +
            (if .test_passed then "" else 
                "<failure message=\"Expected \(.expected_result) but got \(.actual_result)\">" +
                "Example: \(.example_directory)\n" +
                "Policy: \(.policy_directory)\n" +
                "Expected: \(.expected_result)\n" +
                "Actual: \(.actual_result)\n" +
                "Violations: \(.violations | length)" +
                "</failure>"
            end) +
            "</testcase>"'
        
        echo "</testsuite>"
        
    } > "$output_file"
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
    
    local terraform_version conftest_version
    terraform_version=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' || echo "unknown")
    conftest_version=$(conftest --version 2>/dev/null | head -n1 | awk '{print $3}' || echo "unknown")
    
    # Create metadata object
    local metadata
    metadata=$(cat << EOF
{
  "test_metadata": {
    "timestamp": "$timestamp",
    "commit_hash": "$commit_hash",
    "terraform_version": "$terraform_version",
    "conftest_version": "$conftest_version",
    "test_type": "$TEST_TYPE",
    "examples_directory": "$EXAMPLES_DIR",
    "policies_directory": "$POLICIES_DIR"
  }
}
EOF
)
    
    # Read current results
    local current_results
    current_results=$(cat "$json_file")
    
    # Combine metadata with results
    local final_json
    final_json=$(jq -s '.[0] + .[1]' <(echo "$metadata") <(echo "$current_results"))
    
    # Write back to file
    echo "$final_json" > "$json_file"
    
    log_debug "Added metadata to JSON output"
}

# Generate summary statistics
generate_summary() {
    local json_results="$1"
    
    local total_tests passed_tests failed_tests
    total_tests=$(echo "$json_results" | jq '.test_results | length')
    passed_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == true)] | length')
    failed_tests=$(echo "$json_results" | jq '[.test_results[] | select(.test_passed == false)] | length')
    
    log_info "Policy test summary:"
    log_info "  Total tests: $total_tests"
    log_info "  Passed: $passed_tests"
    
    if [[ $failed_tests -gt 0 ]]; then
        log_error "  Failed: $failed_tests"
    else
        log_success "  Failed: $failed_tests"
    fi
    
    return $failed_tests
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting policy test framework"
    
    # Check dependencies
    check_dependencies
    
    # Validate test type
    validate_test_type
    
    # Generate test fixtures if requested
    if [[ "$GENERATE_FIXTURES" == "true" ]]; then
        generate_test_fixtures
    fi
    
    # Generate output file path
    generate_output_file
    
    log_info "Test Type: $TEST_TYPE"
    log_info "Output File: $OUTPUT_FILE"
    log_info "Output Format: $OUTPUT_FORMAT"
    
    # Discover policy directories
    local policy_dirs
    readarray -t policy_dirs < <(discover_policy_directories)
    
    # Discover test examples
    local test_examples
    readarray -t test_examples < <(discover_test_examples "$TEST_TYPE")
    
    if [[ ${#test_examples[@]} -eq 0 ]]; then
        log_warn "No test examples found for test type: $TEST_TYPE"
        log_info "Use -G flag to generate basic test fixtures"
        exit 0
    fi
    
    log_info "Found ${#test_examples[@]} test examples"
    
    # Run tests
    local all_results=()
    local failed_tests=0
    
    for example_dir in "${test_examples[@]}"; do
        # Determine test type for this example
        local current_test_type
        if [[ "$example_dir" =~ /good/ ]]; then
            current_test_type="positive"
        elif [[ "$example_dir" =~ /bad/ ]]; then
            current_test_type="negative"
        else
            log_warn "Cannot determine test type for $example_dir, skipping"
            continue
        fi
        
        # Skip if not matching requested test type
        if [[ "$TEST_TYPE" != "all" ]] && [[ "$TEST_TYPE" != "$current_test_type" ]]; then
            continue
        fi
        
        local example_results exit_code=0
        readarray -t example_results < <(test_example_directory "$example_dir" "$current_test_type" "${policy_dirs[@]}") || exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            ((failed_tests += exit_code))
            if [[ "$FAIL_FAST" == "true" ]]; then
                log_error "Test failed for $example_dir (fail-fast enabled)"
                break
            fi
        fi
        
        all_results+=("${example_results[@]}")
    done
    
    # Combine all results into JSON
    local combined_json='{"test_results": []}'
    for result in "${all_results[@]}"; do
        if [[ -n "$result" ]]; then
            combined_json=$(echo "$combined_json" | jq ".test_results += [$result]")
        fi
    done
    
    # Output results based on format
    case "$OUTPUT_FORMAT" in
        json)
            echo "$combined_json" > "$OUTPUT_FILE"
            add_metadata_to_json "$OUTPUT_FILE"
            ;;
        table)
            format_table_output "$combined_json" "$OUTPUT_FILE"
            ;;
        junit)
            format_junit_output "$combined_json" "$OUTPUT_FILE"
            ;;
    esac
    
    # Generate summary
    local exit_code=0
    generate_summary "$combined_json" || exit_code=$?
    
    # Final status
    if [[ $exit_code -eq 0 ]]; then
        log_success "Policy testing completed successfully"
        log_success "Results saved to: $OUTPUT_FILE"
    else
        log_warn "Policy testing completed with failures"
        log_info "Results saved to: $OUTPUT_FILE"
    fi
    
    # Output the result file path for chaining
    echo "$OUTPUT_FILE"
    
    exit $exit_code
}

# Run main function
main "$@"