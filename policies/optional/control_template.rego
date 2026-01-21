# Multi-Cloud Security Policy Control Templates
# This file provides templates and examples for creating new security controls
# Use the new-control.sh script to generate controls based on these templates

# =============================================================================
# STANDARD CONTROL TEMPLATE
# =============================================================================
# Use this template for regular security controls that are enabled by default

# CONTROL: [DOMAIN]-[NUMBER]
# TITLE: [Brief description of what the control enforces]
# SEVERITY: [CRITICAL|HIGH|MEDIUM|LOW]
# FRAMEWORKS: [Framework mappings, e.g., NIST-800-53:AC-1, CIS-AWS:1.1, ISO-27001:A.9.1.1]
# STATUS: ENABLED

# package terraform.security.[cloud].[domain]
# 
# import rego.v1
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "[terraform_resource_type]"
#     
#     # Add your control logic here
#     # Example: Check if resource violates security policy
#     violates_policy(resource.values)
#     
#     msg := {
#         "control_id": "[DOMAIN]-[NUMBER]",
#         "severity": "[SEVERITY]",
#         "resource": resource.address,
#         "message": "[Description of the violation]",
#         "remediation": "[How to fix the violation]"
#     }
# }
# 
# # Helper function for control logic
# violates_policy(resource_values) if {
#     # Add your validation logic here
#     # Example: Check if security setting is disabled
#     resource_values.security_setting != "enabled"
# }

# =============================================================================
# OPTIONAL CONTROL TEMPLATE
# =============================================================================
# Use this template for optional security controls that are disabled by default

# CONTROL: OPT-[CLOUD]-[DOMAIN]-[NUMBER]
# TITLE: [Brief description of what the control enforces]
# SEVERITY: [CRITICAL|HIGH|MEDIUM|LOW]
# FRAMEWORKS: [Framework mappings, e.g., NIST-800-53:AC-1, CIS-AWS:1.1, ISO-27001:A.9.1.1]
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: [What needs to be in place before enabling this control]
# IMPACT: [How this control will affect operations and workflows]
# CATEGORY: [strict|experimental|environment-specific]

# package terraform.security.[cloud].optional.[domain]
# 
# import rego.v1
# 
# # Main control rule - replace with your specific logic
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "[terraform_resource_type]"
#     
#     # Add your control logic here
#     # Example: Check if resource meets strict security requirements
#     not meets_strict_requirements(resource.values)
#     
#     msg := {
#         "control_id": "OPT-[CLOUD]-[DOMAIN]-[NUMBER]",
#         "severity": "[SEVERITY]",
#         "resource": resource.address,
#         "message": "[Description of the violation]",
#         "remediation": "[How to fix the violation]"
#     }
# }
# 
# # Helper function - replace with your specific logic
# meets_strict_requirements(resource_values) if {
#     # Add your validation logic here
#     # Example: Check if strict security configuration is present
#     resource_values.strict_security_setting == "enabled"
#     resource_values.additional_security_feature == true
# }

# =============================================================================
# CONTROL PATTERN EXAMPLES
# =============================================================================

# Pattern 1: Resource Existence Check
# Ensures required security resources are present
# 
# deny contains msg if {
#     # Check if security resource exists
#     security_resources := [r | r := input.planned_values.root_module.resources[_]; r.type == "aws_security_group"]
#     count(security_resources) == 0
#     
#     msg := {
#         "control_id": "NET-001",
#         "severity": "HIGH",
#         "resource": "root_module",
#         "message": "No security groups defined",
#         "remediation": "Add at least one security group resource"
#     }
# }

# Pattern 2: Configuration Value Check
# Validates specific configuration values
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_s3_bucket"
#     
#     # Check if encryption is disabled
#     not resource.values.server_side_encryption_configuration
#     
#     msg := {
#         "control_id": "DATA-001",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": "S3 bucket encryption is not configured",
#         "remediation": "Add server_side_encryption_configuration block"
#     }
# }

# Pattern 3: Network Security Check
# Validates network access controls
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_security_group_rule"
#     resource.values.type == "ingress"
#     
#     # Check for overly permissive rules
#     resource.values.cidr_blocks[_] == "0.0.0.0/0"
#     resource.values.from_port <= 22
#     resource.values.to_port >= 22
#     
#     msg := {
#         "control_id": "NET-002",
#         "severity": "CRITICAL",
#         "resource": resource.address,
#         "message": "Security group allows SSH access from anywhere",
#         "remediation": "Restrict SSH access to specific IP ranges"
#     }
# }

# Pattern 4: Policy Document Analysis
# Analyzes JSON policy documents
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_iam_policy"
#     
#     # Parse policy document
#     policy_doc := json.unmarshal(resource.values.policy)
#     statement := policy_doc.Statement[_]
#     
#     # Check for overly permissive policies
#     statement.Effect == "Allow"
#     statement.Action[_] == "*"
#     statement.Resource[_] == "*"
#     
#     msg := {
#         "control_id": "IAM-001",
#         "severity": "CRITICAL",
#         "resource": resource.address,
#         "message": "IAM policy allows all actions on all resources",
#         "remediation": "Limit policy to specific actions and resources"
#     }
# }

# Pattern 5: Multi-Resource Relationship Check
# Validates relationships between multiple resources
# 
# deny contains msg if {
#     # Find VPCs without flow logs
#     vpc := input.planned_values.root_module.resources[_]
#     vpc.type == "aws_vpc"
#     
#     # Check if flow log exists for this VPC
#     flow_logs := [fl | fl := input.planned_values.root_module.resources[_]; 
#                   fl.type == "aws_flow_log"; 
#                   fl.values.vpc_id == vpc.values.id]
#     count(flow_logs) == 0
#     
#     msg := {
#         "control_id": "NET-003",
#         "severity": "MEDIUM",
#         "resource": vpc.address,
#         "message": "VPC does not have flow logs enabled",
#         "remediation": "Add aws_flow_log resource for this VPC"
#     }
# }

# Pattern 6: Conditional Logic Based on Environment
# Applies different rules based on resource tags or names
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_instance"
#     
#     # Check if production instance lacks encryption
#     resource.values.tags.Environment == "production"
#     not resource.values.ebs_block_device[_].encrypted
#     
#     msg := {
#         "control_id": "DATA-002",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": "Production instance has unencrypted EBS volumes",
#         "remediation": "Set encrypted = true for all EBS block devices"
#     }
# }

# =============================================================================
# HELPER FUNCTION EXAMPLES
# =============================================================================

# Helper: Check if resource has required tags
# has_required_tags(resource_tags) if {
#     required_tags := ["Environment", "Owner", "Project"]
#     missing_tags := [tag | tag := required_tags[_]; not resource_tags[tag]]
#     count(missing_tags) == 0
# }

# Helper: Check if port is in high-risk range
# is_high_risk_port(port) if {
#     high_risk_ports := [22, 3389, 1433, 3306, 5432, 6379, 27017]
#     port in high_risk_ports
# }

# Helper: Check if CIDR block is public
# is_public_cidr(cidr) if {
#     public_cidrs := ["0.0.0.0/0", "::/0"]
#     cidr in public_cidrs
# }

# Helper: Check if encryption algorithm is approved
# is_approved_encryption(algorithm) if {
#     approved_algorithms := ["AES256", "aws:kms"]
#     algorithm in approved_algorithms
# }

# Template Guidelines:
# 
# 1. Control ID Format:
#    - OPT-AWS-IAM-001 (AWS Identity & Access Management)
#    - OPT-AZ-NET-001 (Azure Networking)
#    - OPT-MULTI-LOG-001 (Multi-cloud Logging)
# 
# 2. Severity Levels:
#    - CRITICAL: Security vulnerabilities that could lead to immediate compromise
#    - HIGH: Significant security risks that should be addressed quickly
#    - MEDIUM: Important security improvements with moderate risk
#    - LOW: Security enhancements and best practices
# 
# 3. Framework Mappings:
#    - NIST-800-53: Use control family and number (e.g., AC-2, IA-5)
#    - CIS: Use benchmark and recommendation number (e.g., CIS-AWS:1.1)
#    - ISO-27001: Use control reference (e.g., A.9.2.1)
# 
# 4. Categories:
#    - strict: Controls that enforce very strict security policies
#    - experimental: Controls under development or testing
#    - environment-specific: Controls for specific environments or use cases
# 
# 5. Prerequisites:
#    - List all requirements that must be met before enabling
#    - Include licensing requirements (e.g., Azure AD Premium)
#    - Mention configuration dependencies
# 
# 6. Impact Assessment:
#    - Describe operational changes required
#    - Mention potential workflow disruptions
#    - Note performance implications if any
# 
# 7. Control Logic Best Practices:
#    - Use clear, readable Rego syntax
#    - Include helper functions for complex logic
#    - Add comments explaining complex conditions
#    - Test with both positive and negative cases
# 
# 8. Error Messages:
#    - Provide clear, actionable violation messages
#    - Include specific remediation steps
#    - Reference relevant documentation when helpful
# 
# 9. Testing:
#    - Create test cases for each control
#    - Test with realistic Terraform configurations
#    - Verify control works in isolation and with other controls
# 
# 10. Documentation:
#     - Update control metadata in control_metadata.json
#     - Add control to appropriate README files
#     - Include examples in documentation

# =============================================================================
# CONTROL VALIDATION GUIDELINES
# =============================================================================

# 1. Control ID Format:
#    - Standard controls: [DOMAIN]-[NUMBER] (e.g., IAM-010, NET-020)
#    - Optional controls: OPT-[CLOUD]-[DOMAIN]-[NUMBER] (e.g., OPT-AWS-IAM-010)
#    - Use 3-digit numbers with leading zeros (001, 010, 100)

# 2. Severity Levels:
#    - CRITICAL: Security vulnerabilities that could lead to immediate compromise
#    - HIGH: Significant security risks that should be addressed quickly
#    - MEDIUM: Important security improvements with moderate risk
#    - LOW: Security enhancements and best practices

# 3. Framework Mappings:
#    - NIST-800-53: Use control family and number (e.g., AC-2, IA-5)
#    - CIS-AWS: Use benchmark and recommendation number (e.g., CIS-AWS:1.1)
#    - CIS-Azure: Use benchmark and recommendation number (e.g., CIS-Azure:1.1)
#    - ISO-27001: Use control reference (e.g., A.9.2.1)

# 4. Optional Control Categories:
#    - strict: Controls that enforce very strict security policies
#    - experimental: Controls under development or testing
#    - environment-specific: Controls for specific environments or use cases

# 5. Prerequisites:
#    - List all requirements that must be met before enabling
#    - Include licensing requirements (e.g., Azure AD Premium)
#    - Mention configuration dependencies

# 6. Impact Assessment:
#    - Describe operational changes required
#    - Mention potential workflow disruptions
#    - Note performance implications if any

# 7. Control Logic Best Practices:
#    - Use clear, readable Rego syntax
#    - Include helper functions for complex logic
#    - Add comments explaining complex conditions
#    - Test with both positive and negative cases

# 8. Error Messages:
#    - Provide clear, actionable violation messages
#    - Include specific remediation steps
#    - Reference relevant documentation when helpful

# 9. Testing Requirements:
#    - Create test cases for each control
#    - Test with realistic Terraform configurations
#    - Verify control works in isolation and with other controls

# 10. Documentation:
#     - Update control metadata in control_metadata.json
#     - Add control to appropriate README files
#     - Include examples in documentation

# =============================================================================
# COMMON REGO PATTERNS AND UTILITIES
# =============================================================================

# Pattern: Iterate over all resources of a specific type
# resources_of_type(resource_type) := [r | r := input.planned_values.root_module.resources[_]; r.type == resource_type]

# Pattern: Check if any resource violates a condition
# has_violation if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "target_type"
#     violates_condition(resource.values)
# }

# Pattern: Count resources matching criteria
# count_matching_resources(resource_type, condition) := count([r | 
#     r := input.planned_values.root_module.resources[_]; 
#     r.type == resource_type; 
#     condition(r.values)
# ])

# Pattern: Find resources missing required configuration
# missing_config(resource_type, config_path) := [r | 
#     r := input.planned_values.root_module.resources[_]; 
#     r.type == resource_type; 
#     not object.get(r.values, config_path, false)
# ]

# Pattern: Validate JSON policy documents
# validate_policy_document(policy_json) if {
#     policy := json.unmarshal(policy_json)
#     # Add validation logic for policy structure
# }

# Pattern: Check resource relationships
# has_dependent_resource(main_resource, dependent_type, relationship_field) if {
#     dependent := input.planned_values.root_module.resources[_]
#     dependent.type == dependent_type
#     dependent.values[relationship_field] == main_resource.values.id
# }