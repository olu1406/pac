#!/bin/bash

# Multi-Cloud Security Policy Scanner
# Main orchestration script for policy validation

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="$PROJECT_ROOT/policies"
EXAMPLES_DIR="$PROJECT_ROOT/examples"
REPORTS_DIR="$PROJECT_ROOT/reports"

# Default configuration
TERRAFORM_DIR="${TERRAFORM_DIR:-$PWD}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
SEVERITY_FILTER="${SEVERITY_FILTER:-all}"
ENVIRONMENT="${ENVIRONMENT:-local}"
VERBOSE="${VERBOSE:-false}"

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

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Multi-Cloud Security Policy Scanner

OPTIONS:
    -d, --terraform-dir DIR     Terraform directory to scan (default: current directory)
    -o, --output FORMAT         Output format: json, markdown, both (default: json)
    -s, --severity LEVEL        Filter by severity: low, medium, high, critical, all (default: all)
    -e, --environment ENV       Environment name for reporting (default: local)
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                          # Scan current directory with default settings
    $0 -d ./terraform -o both   # Scan specific directory with both output formats
    $0 -s high -e production    # Filter high severity violations in production environment

ENVIRONMENT VARIABLES:
    TERRAFORM_DIR               Override default terraform directory
    OUTPUT_FORMAT               Override default output format
    SEVERITY_FILTER             Override default severity filter
    ENVIRONMENT                 Override default environment name
    VERBOSE                     Enable verbose output (true/false)

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--terraform-dir)
                TERRAFORM_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -s|--severity)
                SEVERITY_FILTER="$2"
                shift 2
                ;;
            -e|--environment)
                ENVIRONMENT="$2"
                shift 2
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
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if ! command -v conftest &> /dev/null; then
        missing_deps+=("conftest")
    fi
    
    if ! command -v opa &> /dev/null; then
        missing_deps+=("opa")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Please install the missing dependencies and try again"
        exit 1
    fi
}

# Validate terraform directory
validate_terraform_dir() {
    if [[ ! -d "$TERRAFORM_DIR" ]]; then
        log_error "Terraform directory does not exist: $TERRAFORM_DIR"
        exit 1
    fi
    
    if [[ ! -f "$TERRAFORM_DIR"/*.tf ]] && [[ ! -f "$TERRAFORM_DIR"/**/*.tf ]]; then
        log_warn "No Terraform files found in: $TERRAFORM_DIR"
    fi
}

# Generate terraform plan JSON
generate_plan() {
    local plan_file="$REPORTS_DIR/terraform.tfplan"
    local plan_json="$REPORTS_DIR/terraform-plan.json"
    
    log_info "Generating Terraform plan..."
    
    cd "$TERRAFORM_DIR"
    
    # Initialize terraform if needed
    if [[ ! -d ".terraform" ]]; then
        log_info "Initializing Terraform..."
        terraform init -input=false
    fi
    
    # Generate plan
    if ! terraform plan -input=false -out="$plan_file"; then
        log_error "Failed to generate Terraform plan"
        exit 1
    fi
    
    # Convert plan to JSON
    if ! terraform show -json "$plan_file" > "$plan_json"; then
        log_error "Failed to convert plan to JSON"
        exit 1
    fi
    
    log_success "Terraform plan generated: $plan_json"
    echo "$plan_json"
}

# Run policy validation
run_policies() {
    local plan_json="$1"
    local violations_json="$REPORTS_DIR/violations.json"
    
    log_info "Running policy validation..."
    
    if [[ ! -d "$POLICIES_DIR" ]]; then
        log_error "Policies directory not found: $POLICIES_DIR"
        exit 1
    fi
    
    # Run conftest with all policies
    if conftest verify --policy "$POLICIES_DIR" --output json "$plan_json" > "$violations_json" 2>/dev/null; then
        log_success "No policy violations found"
        echo "[]" > "$violations_json"
    else
        log_warn "Policy violations detected"
    fi
    
    echo "$violations_json"
}

# Generate reports
generate_reports() {
    local violations_json="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    # Create report metadata
    local metadata=$(cat << EOF
{
  "scan_metadata": {
    "timestamp": "$timestamp",
    "environment": "$ENVIRONMENT",
    "commit_hash": "$commit_hash",
    "scan_mode": "local",
    "terraform_version": "$(terraform version -json | jq -r '.terraform_version')",
    "conftest_version": "$(conftest --version | head -n1 | awk '{print $3}')"
  }
}
EOF
)
    
    # Generate JSON report
    if [[ "$OUTPUT_FORMAT" == "json" || "$OUTPUT_FORMAT" == "both" ]]; then
        local json_report="$REPORTS_DIR/scan-report.json"
        jq -s ".[0] + {\"violations\": .[1]}" <(echo "$metadata") "$violations_json" > "$json_report"
        log_success "JSON report generated: $json_report"
    fi
    
    # Generate Markdown report
    if [[ "$OUTPUT_FORMAT" == "markdown" || "$OUTPUT_FORMAT" == "both" ]]; then
        local md_report="$REPORTS_DIR/scan-report.md"
        generate_markdown_report "$violations_json" "$metadata" > "$md_report"
        log_success "Markdown report generated: $md_report"
    fi
}

# Generate markdown report
generate_markdown_report() {
    local violations_json="$1"
    local metadata="$2"
    local timestamp=$(echo "$metadata" | jq -r '.scan_metadata.timestamp')
    local environment=$(echo "$metadata" | jq -r '.scan_metadata.environment')
    local commit_hash=$(echo "$metadata" | jq -r '.scan_metadata.commit_hash')
    
    cat << EOF
# Security Policy Scan Report

**Scan Date:** $timestamp  
**Environment:** $environment  
**Commit:** $commit_hash  

## Summary

$(jq -r 'length as $total | if $total == 0 then "✅ No policy violations found" else "⚠️  \($total) policy violation(s) detected" end' "$violations_json")

## Violations

$(jq -r '.[] | "### \(.control_id): \(.message)\n\n**Severity:** \(.severity)  \n**Resource:** \(.resource_address)  \n**Remediation:** \(.remediation)\n"' "$violations_json")

---
*Generated by Multi-Cloud Security Policy Scanner*
EOF
}

# Cleanup function
cleanup() {
    if [[ "$VERBOSE" == "false" ]]; then
        rm -f "$REPORTS_DIR/terraform.tfplan" 2>/dev/null || true
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    log_info "Starting Multi-Cloud Security Policy Scanner"
    log_info "Terraform Directory: $TERRAFORM_DIR"
    log_info "Output Format: $OUTPUT_FORMAT"
    log_info "Environment: $ENVIRONMENT"
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
    
    # Validate dependencies and configuration
    check_dependencies
    validate_terraform_dir
    
    # Generate plan and run policies
    local plan_json
    plan_json=$(generate_plan)
    
    local violations_json
    violations_json=$(run_policies "$plan_json")
    
    # Generate reports
    generate_reports "$violations_json"
    
    # Cleanup
    cleanup
    
    # Exit with appropriate code
    local violation_count
    violation_count=$(jq 'length' "$violations_json")
    
    if [[ "$violation_count" -eq 0 ]]; then
        log_success "Scan completed successfully - no violations found"
        exit 0
    else
        log_warn "Scan completed with $violation_count violation(s)"
        exit 1
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"