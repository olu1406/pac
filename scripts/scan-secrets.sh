#!/bin/bash

# Multi-Cloud Security Policy - Secret Scanner
# Detects hardcoded secrets and credentials in the repository
# Implements secure logging without sensitive data exposure

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REPORTS_DIR="$PROJECT_ROOT/reports"
AUDIT_LOG="$REPORTS_DIR/security-audit.log"

# Default configuration
SCAN_DIR="${SCAN_DIR:-$PROJECT_ROOT}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-json}"
VERBOSE="${VERBOSE:-false}"
EXCLUDE_DIRS="${EXCLUDE_DIRS:-.git,.terraform,node_modules,reports}"
EXCLUDE_FILES="${EXCLUDE_FILES:-*.log,*.tfplan,*.tfstate,*.tfstate.backup}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions (consistent with other scripts)
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

# Secure audit logging function - logs security events without exposing sensitive data
log_security_event() {
    local event_type="$1"
    local severity="$2"
    local description="$3"
    local file_path="${4:-}"
    local line_number="${5:-}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    local user=$(whoami 2>/dev/null || echo "unknown")
    
    # Ensure audit log directory exists
    mkdir -p "$(dirname "$AUDIT_LOG")"
    
    # Create audit log entry (JSON format for structured logging)
    # Use printf to avoid issues with special characters
    printf '{"timestamp":"%s","event_type":"%s","severity":"%s","description":"%s","file_path":"%s","line_number":"%s","commit_hash":"%s","user":"%s","scanner_version":"1.0.0"}\n' \
        "$timestamp" "$event_type" "$severity" "$description" "$file_path" "$line_number" "$commit_hash" "$user" >> "$AUDIT_LOG"
    
    log_debug "Security event logged: $event_type ($severity)"
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Multi-Cloud Security Policy - Secret Scanner
Detects hardcoded secrets and credentials in the repository

OPTIONS:
    -d, --scan-dir DIR          Directory to scan (default: project root)
    -o, --output FORMAT         Output format: json, text, both (default: json)
    -e, --exclude-dirs DIRS     Comma-separated list of directories to exclude
    -f, --exclude-files FILES   Comma-separated list of file patterns to exclude
    -v, --verbose               Enable verbose output
    -h, --help                  Show this help message

EXAMPLES:
    $0                          # Scan project root with default settings
    $0 -d ./modules -o both     # Scan modules directory with both output formats
    $0 -v                       # Scan with verbose output

ENVIRONMENT VARIABLES:
    SCAN_DIR                    Override default scan directory
    OUTPUT_FORMAT               Override default output format
    VERBOSE                     Enable verbose output (true/false)
    EXCLUDE_DIRS                Override default excluded directories
    EXCLUDE_FILES               Override default excluded file patterns

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--scan-dir)
                SCAN_DIR="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -e|--exclude-dirs)
                EXCLUDE_DIRS="$2"
                shift 2
                ;;
            -f|--exclude-files)
                EXCLUDE_FILES="$2"
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

# Validate configuration
validate_config() {
    if [[ ! -d "$SCAN_DIR" ]]; then
        log_error "Scan directory does not exist: $SCAN_DIR"
        exit 1
    fi
    
    case "$OUTPUT_FORMAT" in
        json|text|both)
            log_debug "Output format validated: $OUTPUT_FORMAT"
            ;;
        *)
            log_error "Invalid output format: $OUTPUT_FORMAT"
            log_info "Supported formats: json, text, both"
            exit 1
            ;;
    esac
    
    # Create reports directory
    mkdir -p "$REPORTS_DIR"
}

# Check if a credential appears to be an example/dummy credential
is_example_credential() {
    local text="$1"
    
    # Common AWS example credentials
    if [[ "$text" =~ AKIAIOSFODNN7EXAMPLE ]] || \
       [[ "$text" =~ wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY ]] || \
       [[ "$text" =~ EXAMPLE ]] || \
       [[ "$text" =~ example ]] || \
       [[ "$text" =~ dummy ]] || \
       [[ "$text" =~ DUMMY ]] || \
       [[ "$text" =~ test ]] || \
       [[ "$text" =~ TEST ]] || \
       [[ "$text" =~ placeholder ]] || \
       [[ "$text" =~ PLACEHOLDER ]] || \
       [[ "$text" =~ your-.*-here ]] || \
       [[ "$text" =~ YOUR.*HERE ]]; then
        return 0  # Is example
    fi
    
    return 1  # Not example
}

# Define secret patterns to detect
# These patterns are designed to catch common secret formats without being overly broad
get_secret_patterns() {
    cat << 'EOF'
# AWS Access Keys (excluding common examples)
AKIA[0-9A-Z]{16}:AWS Access Key ID:CRITICAL

# Generic API Keys and Tokens (with word boundaries, excluding examples)
\b[Aa]pi[_-]?[Kk]ey["\s]*[:=]["\s]*[A-Za-z0-9_-]{20,}\b:API Key (potential):HIGH
\b[Tt]oken["\s]*[:=]["\s]*[A-Za-z0-9_-]{20,}\b:Token (potential):HIGH
\b[Ss]ecret["\s]*[:=]["\s]*[A-Za-z0-9_-]{20,}\b:Secret (potential):HIGH

# Database Connection Strings
\b[Pp]assword["\s]*[:=]["\s]*[^"\s]{8,}\b:Database Password (potential):HIGH

# Private Keys (headers)
-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----:Private Key:CRITICAL
-----BEGIN\s+OPENSSH\s+PRIVATE\s+KEY-----:OpenSSH Private Key:CRITICAL

# Common secret variable names with values
\b[Aa]ccess[_-]?[Kk]ey["\s]*[:=]["\s]*[A-Za-z0-9_-]{16,}\b:Access Key (potential):HIGH
\b[Ss]ecret[_-]?[Kk]ey["\s]*[:=]["\s]*[A-Za-z0-9_-]{16,}\b:Secret Key (potential):HIGH
\b[Aa]uth[_-]?[Tt]oken["\s]*[:=]["\s]*[A-Za-z0-9_-]{16,}\b:Auth Token (potential):HIGH
EOF
}

# Build find command with exclusions
build_find_command() {
    local find_cmd="find \"$SCAN_DIR\" -type f"
    
    # Add directory exclusions
    if [[ -n "$EXCLUDE_DIRS" ]]; then
        IFS=',' read -ra DIRS <<< "$EXCLUDE_DIRS"
        for dir in "${DIRS[@]}"; do
            find_cmd="$find_cmd -not -path \"*/$dir/*\""
        done
    fi
    
    # Add file exclusions
    if [[ -n "$EXCLUDE_FILES" ]]; then
        IFS=',' read -ra FILES <<< "$EXCLUDE_FILES"
        for file_pattern in "${FILES[@]}"; do
            find_cmd="$find_cmd -not -name \"$file_pattern\""
        done
    fi
    
    echo "$find_cmd"
}

# Scan a single file for secrets
scan_file() {
    local file_path="$1"
    local findings_count=0
    
    log_debug "Scanning file: $file_path"
    
    # Skip binary files
    if ! file "$file_path" | grep -q "text"; then
        log_debug "Skipping binary file: $file_path"
        echo "[]"
        return 0
    fi
    
    # Create temporary file for findings
    local temp_findings="$REPORTS_DIR/temp_file_findings_$$.json"
    echo "[]" > "$temp_findings"
    
    # Read secret patterns and scan
    while IFS=':' read -r pattern description severity; do
        # Skip comments and empty lines
        [[ "$pattern" =~ ^#.*$ ]] || [[ -z "$pattern" ]] && continue
        
        # Search for pattern in file
        local matches
        matches=$(grep -n -E "$pattern" "$file_path" 2>/dev/null || true)
        
        if [[ -n "$matches" ]]; then
            while IFS= read -r match_line; do
                # Skip empty lines
                [[ -z "$match_line" ]] && continue
                
                # Extract line number and match text
                local line_num="${match_line%%:*}"
                local match_text="${match_line#*:}"
                
                # Skip if we couldn't parse properly
                [[ -z "$line_num" ]] || [[ -z "$match_text" ]] && continue
                
                # Skip known example/dummy credentials
                if is_example_credential "$match_text"; then
                    log_debug "Skipping example credential in $file_path:$line_num"
                    continue
                fi
                
                # Sanitize match text for logging (truncate and mask potential secrets)
                local sanitized_match
                sanitized_match=$(echo "$match_text" | sed 's/[A-Za-z0-9+/=]\{8,\}/[REDACTED]/g' | cut -c1-100)
                
                # Create finding and append to temp file
                jq --arg file "$file_path" \
                   --arg line "$line_num" \
                   --arg pattern "$description" \
                   --arg severity "$severity" \
                   --arg preview "$sanitized_match" \
                   '. += [{
                       "file": $file,
                       "line": ($line | tonumber),
                       "pattern": $pattern,
                       "severity": $severity,
                       "match_preview": $preview
                   }]' "$temp_findings" > "${temp_findings}.tmp" && mv "${temp_findings}.tmp" "$temp_findings"
                
                ((findings_count++))
                
                # Log security event
                log_security_event "SECRET_DETECTED" "$severity" "$description detected in file" "$file_path" "$line_num"
                
            done <<< "$matches"
        fi
    done < <(get_secret_patterns)
    
    # Return findings
    cat "$temp_findings"
    rm -f "$temp_findings"
}

# Scan all files in the directory
scan_directory() {
    local findings_file="$REPORTS_DIR/temp_findings.jsonl"
    local file_count=0
    local scanned_count=0
    
    # Remove any existing temp file
    rm -f "$findings_file"
    
    log_info "Starting secret scan of directory: $SCAN_DIR"
    log_security_event "SCAN_STARTED" "INFO" "Secret scan initiated" "$SCAN_DIR"
    
    # Build and execute find command
    local find_cmd
    find_cmd=$(build_find_command)
    
    log_debug "Find command: $find_cmd"
    
    # Count total files to scan
    file_count=$(eval "$find_cmd" | wc -l)
    log_info "Found $file_count files to scan"
    
    # Scan each file
    while IFS= read -r file_path; do
        ((scanned_count++))
        
        if [[ $((scanned_count % 100)) -eq 0 ]] || [[ "$VERBOSE" == "true" ]]; then
            log_info "Progress: $scanned_count/$file_count files scanned"
        fi
        
        local file_findings
        file_findings=$(scan_file "$file_path")
        
        if [[ "$file_findings" != "[]" ]]; then
            # Append findings to JSONL file (one JSON object per line)
            echo "$file_findings" | jq -c '.[]' >> "$findings_file"
        fi
        
    done < <(eval "$find_cmd")
    
    log_info "Scan completed: $scanned_count files scanned"
    
    # Convert JSONL to JSON array
    if [[ -f "$findings_file" && -s "$findings_file" ]]; then
        jq -s '.' "$findings_file"
    else
        echo "[]"
    fi
    
    # Clean up temp file
    rm -f "$findings_file"
}

# Generate text report
generate_text_report() {
    local findings="$1"
    local output_file="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat << EOF > "$output_file"
# Secret Scan Report

**Scan Date:** $timestamp  
**Scan Directory:** $SCAN_DIR  
**Scanner Version:** 1.0.0  

## Summary

$(echo "$findings" | jq -r 'length as $total | if $total == 0 then "✅ No secrets detected" else "⚠️  \($total) potential secret(s) detected" end')

$(echo "$findings" | jq -r 'if length > 0 then "### Findings by Severity\n" + (group_by(.severity) | map("**\(.[0].severity):** \(length) finding(s)") | join("\n")) else "" end')

## Detailed Findings

$(echo "$findings" | jq -r '.[] | "### \(.pattern) (\(.severity))\n\n**File:** \(.file)  \n**Line:** \(.line)  \n**Preview:** \(.match_preview)\n\n---\n"')

## Remediation Guidance

If secrets were detected:
1. **Immediately rotate** any exposed credentials
2. **Remove secrets** from code and commit history
3. **Use secure alternatives:**
   - Environment variables for runtime secrets
   - AWS Systems Manager Parameter Store or Secrets Manager
   - Azure Key Vault
   - HashiCorp Vault
   - Kubernetes Secrets

## Security Best Practices

- Never commit secrets to version control
- Use .gitignore to exclude sensitive files
- Implement pre-commit hooks for secret detection
- Use infrastructure-as-code for secret management
- Regularly audit and rotate credentials

---
*Generated by Multi-Cloud Security Policy Secret Scanner*
EOF
}

# Generate JSON report
generate_json_report() {
    local findings="$1"
    local output_file="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local commit_hash=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    log_debug "Generating JSON report with findings: $findings"
    
    # Validate findings JSON first
    if ! echo "$findings" | jq empty 2>/dev/null; then
        log_error "Invalid findings JSON, creating empty report"
        findings="[]"
    fi
    
    # Create comprehensive JSON report
    jq -n \
        --arg timestamp "$timestamp" \
        --arg scan_dir "$SCAN_DIR" \
        --arg commit_hash "$commit_hash" \
        --arg scanner_version "1.0.0" \
        --argjson findings "$findings" \
        '{
            "scan_metadata": {
                "timestamp": $timestamp,
                "scan_directory": $scan_dir,
                "commit_hash": $commit_hash,
                "scanner_version": $scanner_version,
                "scan_type": "secret_detection"
            },
            "summary": {
                "total_findings": ($findings | length),
                "findings_by_severity": ($findings | group_by(.severity) | map({key: .[0].severity, value: length}) | from_entries)
            },
            "findings": $findings,
            "remediation": {
                "immediate_actions": [
                    "Rotate any exposed credentials immediately",
                    "Remove secrets from code and commit history",
                    "Implement secure secret management"
                ],
                "prevention_measures": [
                    "Use environment variables for runtime secrets",
                    "Implement pre-commit hooks for secret detection",
                    "Use cloud-native secret management services",
                    "Regular security audits and credential rotation"
                ]
            }
        }' > "$output_file"
}

# Generate reports
generate_reports() {
    local findings="$1"
    local timestamp=$(date -u +"%Y%m%d_%H%M%S")
    
    # Generate JSON report
    if [[ "$OUTPUT_FORMAT" == "json" || "$OUTPUT_FORMAT" == "both" ]]; then
        local json_report="$REPORTS_DIR/secret-scan-report_${timestamp}.json"
        generate_json_report "$findings" "$json_report"
        log_success "JSON report generated: $json_report"
    fi
    
    # Generate text report
    if [[ "$OUTPUT_FORMAT" == "text" || "$OUTPUT_FORMAT" == "both" ]]; then
        local text_report="$REPORTS_DIR/secret-scan-report_${timestamp}.md"
        generate_text_report "$findings" "$text_report"
        log_success "Text report generated: $text_report"
    fi
}

# Display summary
display_summary() {
    local findings="$1"
    local finding_count
    finding_count=$(echo "$findings" | jq 'length')
    
    log_info "=== Secret Scan Summary ==="
    
    if [[ "$finding_count" -eq 0 ]]; then
        log_success "No secrets detected in the repository"
        log_security_event "SCAN_COMPLETED" "INFO" "Secret scan completed successfully - no secrets found"
    else
        log_warn "$finding_count potential secret(s) detected"
        
        # Show severity breakdown
        echo "$findings" | jq -r 'group_by(.severity) | map("  \(.[0].severity): \(length) finding(s)") | join("\n")' | while read -r line; do
            log_warn "$line"
        done
        
        log_security_event "SCAN_COMPLETED" "WARN" "Secret scan completed with findings" "" "$finding_count"
    fi
    
    log_info "Audit log: $AUDIT_LOG"
}

# Main execution
main() {
    parse_args "$@"
    validate_config
    
    log_info "Starting Multi-Cloud Security Policy Secret Scanner"
    log_info "Scan Directory: $SCAN_DIR"
    log_info "Output Format: $OUTPUT_FORMAT"
    log_info "Excluded Directories: $EXCLUDE_DIRS"
    log_info "Excluded Files: $EXCLUDE_FILES"
    
    # Perform the scan
    local findings
    log_debug "About to start directory scan"
    findings=$(scan_directory)
    log_debug "Directory scan completed, findings length: $(echo "$findings" | jq 'length' 2>/dev/null || echo 'ERROR')"
    
    # Generate reports
    log_debug "About to generate reports"
    generate_reports "$findings"
    log_debug "Reports generated successfully"
    
    # Display summary
    display_summary "$findings"
    
    # Exit with appropriate code
    local finding_count
    finding_count=$(echo "$findings" | jq 'length')
    
    if [[ "$finding_count" -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Run main function
main "$@"