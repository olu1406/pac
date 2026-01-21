#!/bin/bash

# Export Compliance Matrix Script
# Generates compliance matrices in CSV and JSON formats from control metadata

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
POLICIES_DIR="$PROJECT_ROOT/policies"
REPORTS_DIR="$PROJECT_ROOT/reports"
METADATA_FILE="$POLICIES_DIR/control_metadata.json"

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

# Function to print usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -f, --format FORMAT    Output format: csv, json, or both (default: both)"
    echo "  -o, --output DIR       Output directory (default: reports/)"
    echo "  -h, --help            Show this help message"
    exit 1
}

# Parse command line arguments
FORMAT="both"
OUTPUT_DIR="$REPORTS_DIR"

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate format
if [[ ! "$FORMAT" =~ ^(csv|json|both)$ ]]; then
    echo "Error: Invalid format '$FORMAT'. Must be csv, json, or both."
    exit 1
fi

# Check if metadata file exists
if [[ ! -f "$METADATA_FILE" ]]; then
    echo "Error: Control metadata file not found at $METADATA_FILE"
    exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq to continue."
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Exporting compliance matrices..."
echo "Source: $METADATA_FILE"
echo "Output: $OUTPUT_DIR"
echo "Format: $FORMAT"

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_SUFFIX=$(date +"%Y%m%d_%H%M%S")

# Export JSON format
if [[ "$FORMAT" == "json" || "$FORMAT" == "both" ]]; then
    echo "Generating JSON compliance matrix..."
    
    JSON_OUTPUT="$OUTPUT_DIR/compliance_matrix_$DATE_SUFFIX.json"
    
    jq -n --argjson metadata "$(jq '.metadata' "$METADATA_FILE")" \
          --argjson controls "$(jq '.controls' "$METADATA_FILE")" \
          --arg timestamp "$TIMESTAMP" '
    {
        "export_metadata": {
            "timestamp": $timestamp,
            "format": "json",
            "source": "control_metadata.json"
        },
        "control_metadata": $metadata,
        "frameworks": {
            "nist_800_53": [
                $controls | to_entries[] | 
                select(.value.frameworks.nist_800_53) | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "domain": .value.domain,
                    "nist_controls": .value.frameworks.nist_800_53
                }
            ],
            "cis": [
                $controls | to_entries[] | 
                select(.value.frameworks.cis_aws or .value.frameworks.cis_azure) | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "domain": .value.domain,
                    "cis_controls": (
                        if .value.frameworks.cis_aws then .value.frameworks.cis_aws
                        else .value.frameworks.cis_azure end
                    )
                }
            ],
            "iso_27001": [
                $controls | to_entries[] | 
                select(.value.frameworks.iso_27001) | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "domain": .value.domain,
                    "iso_controls": .value.frameworks.iso_27001
                }
            ]
        },
        "controls_by_cloud": {
            "aws": [
                $controls | to_entries[] | 
                select(.value.cloud_provider == "aws") | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "domain": .value.domain,
                    "frameworks": .value.frameworks
                }
            ],
            "azure": [
                $controls | to_entries[] | 
                select(.value.cloud_provider == "azure") | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "domain": .value.domain,
                    "frameworks": .value.frameworks
                }
            ]
        },
        "controls_by_domain": {
            "identity": [
                $controls | to_entries[] | 
                select(.value.domain == "identity") | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "frameworks": .value.frameworks
                }
            ],
            "networking": [
                $controls | to_entries[] | 
                select(.value.domain == "networking") | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "frameworks": .value.frameworks
                }
            ],
            "logging": [
                $controls | to_entries[] | 
                select(.value.domain == "logging") | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "frameworks": .value.frameworks
                }
            ],
            "data": [
                $controls | to_entries[] | 
                select(.value.domain == "data") | 
                {
                    "control_id": .key,
                    "title": .value.title,
                    "severity": .value.severity,
                    "cloud_provider": .value.cloud_provider,
                    "frameworks": .value.frameworks
                }
            ]
        }
    }' > "$JSON_OUTPUT"
    
    echo "JSON matrix exported to: $JSON_OUTPUT"
fi

# Export CSV format
if [[ "$FORMAT" == "csv" || "$FORMAT" == "both" ]]; then
    echo "Generating CSV compliance matrix..."
    
    CSV_OUTPUT="$OUTPUT_DIR/compliance_matrix_$DATE_SUFFIX.csv"
    
    # Create CSV header
    echo "Control_ID,Title,Severity,Cloud_Provider,Domain,NIST_800_53,CIS,ISO_27001,Policy_File,Description,Remediation" > "$CSV_OUTPUT"
    
    # Extract control data and convert to CSV
    jq -r '.controls | to_entries[] | 
        [
            .key,
            .value.title,
            .value.severity,
            .value.cloud_provider,
            .value.domain,
            (.value.frameworks.nist_800_53 // [] | join(";")),
            ((.value.frameworks.cis_aws // []) + (.value.frameworks.cis_azure // []) | join(";")),
            (.value.frameworks.iso_27001 // [] | join(";")),
            .value.policy_file,
            .value.description,
            .value.remediation
        ] | @csv' "$METADATA_FILE" >> "$CSV_OUTPUT"
    
    echo "CSV matrix exported to: $CSV_OUTPUT"
fi

# Generate summary statistics
echo ""
echo "=== Compliance Matrix Summary ==="
echo "Total Controls: $(jq '.metadata.total_controls' "$METADATA_FILE")"
echo "AWS Controls: $(jq '.metadata.aws_controls' "$METADATA_FILE")"
echo "Azure Controls: $(jq '.metadata.azure_controls' "$METADATA_FILE")"
echo ""
echo "Controls by Severity:"
jq -r '.controls | group_by(.severity) | .[] | "\(.length) \(.[0].severity) controls"' "$METADATA_FILE" | sort -nr
echo ""
echo "Controls by Domain:"
jq -r '.controls | group_by(.domain) | .[] | "\(.length) \(.[0].domain) controls"' "$METADATA_FILE" | sort -nr
echo ""
echo "Framework Coverage:"
echo "- NIST 800-53: $(jq '[.controls[] | select(.frameworks.nist_800_53)] | length' "$METADATA_FILE") controls"
echo "- CIS Benchmarks: $(jq '[.controls[] | select(.frameworks.cis_aws or .frameworks.cis_azure)] | length' "$METADATA_FILE") controls"
echo "- ISO 27001: $(jq '[.controls[] | select(.frameworks.iso_27001)] | length' "$METADATA_FILE") controls"

echo ""
echo "Compliance matrix export completed successfully!"