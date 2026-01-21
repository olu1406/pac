# Optional AWS IAM Controls - Strict Security Policies
# These controls enforce stricter IAM security policies that may impact operational flexibility
# Enable these controls only after careful consideration of operational impact

# CONTROL: OPT-AWS-IAM-001
# TITLE: Require MFA for all API access
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:IA-2, CIS-AWS:1.2, ISO-27001:A.9.4.2
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: MFA devices configured for all users
# IMPACT: May break automated processes that don't support MFA

# package terraform.security.aws.optional.strict_iam
# 
# import rego.v1
# 
# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_iam_user"
#     
#     # Check if user has console access but no MFA requirement
#     user_name := resource.values.name
#     not has_mfa_requirement(user_name)
#     has_console_access(user_name)
#     
#     msg := {
#         "control_id": "OPT-AWS-IAM-001",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": "IAM user with console access must have MFA requirement enforced",
#         "remediation": "Add conditional policy requiring MFA for console access or attach MFA device"
#     }
# }
# 
# has_mfa_requirement(user_name) if {
#     policy := input.planned_values.root_module.resources[_]
#     policy.type == "aws_iam_user_policy"
#     policy.values.user == user_name
#     policy_doc := json.unmarshal(policy.values.policy)
#     statement := policy_doc.Statement[_]
#     statement.Condition.Bool["aws:MultiFactorAuthPresent"]
# }
# 
# has_console_access(user_name) if {
#     profile := input.planned_values.root_module.resources[_]
#     profile.type == "aws_iam_user_login_profile"
#     profile.values.user == user_name
# }

# CONTROL: OPT-AWS-IAM-002
# TITLE: Enforce password complexity beyond baseline requirements
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:IA-5, CIS-AWS:1.8, ISO-27001:A.9.4.3
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Users must be prepared for stricter password requirements
# IMPACT: May require users to change existing passwords

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_iam_account_password_policy"
#     
#     # Enforce stricter requirements than baseline
#     not meets_strict_password_requirements(resource.values)
#     
#     msg := {
#         "control_id": "OPT-AWS-IAM-002",
#         "severity": "MEDIUM",
#         "resource": resource.address,
#         "message": "Password policy must meet strict security requirements",
#         "remediation": "Set minimum_password_length >= 16, require_symbols = true, require_numbers = true, require_uppercase_characters = true, require_lowercase_characters = true, password_reuse_prevention >= 12"
#     }
# }
# 
# meets_strict_password_requirements(policy) if {
#     policy.minimum_password_length >= 16
#     policy.require_symbols == true
#     policy.require_numbers == true
#     policy.require_uppercase_characters == true
#     policy.require_lowercase_characters == true
#     policy.password_reuse_prevention >= 12
#     policy.max_password_age <= 60
# }

# CONTROL: OPT-AWS-IAM-003
# TITLE: Require IAM role session duration limits
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-2, CIS-AWS:1.17, ISO-27001:A.9.2.1
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Applications must handle session renewal
# IMPACT: May require application changes to handle shorter sessions

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_iam_role"
#     
#     # Check for overly long session duration
#     not has_appropriate_session_duration(resource.values)
#     
#     msg := {
#         "control_id": "OPT-AWS-IAM-003",
#         "severity": "MEDIUM",
#         "resource": resource.address,
#         "message": "IAM role session duration exceeds security policy limits",
#         "remediation": "Set max_session_duration to 3600 seconds (1 hour) or less for security roles"
#     }
# }
# 
# has_appropriate_session_duration(role) if {
#     role.max_session_duration <= 3600
# }
# 
# has_appropriate_session_duration(role) if {
#     not role.max_session_duration  # Default is acceptable
# }

# CONTROL: OPT-AWS-IAM-004
# TITLE: Require explicit deny for sensitive actions
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-6, CIS-AWS:1.16, ISO-27001:A.9.2.3
# STATUS: DISABLED (uncomment to enable)
# OPTIONAL: true
# PREREQUISITES: Review all existing policies for compatibility
# IMPACT: May break existing workflows that rely on implicit permissions

# deny contains msg if {
#     resource := input.planned_values.root_module.resources[_]
#     resource.type == "aws_iam_policy"
#     policy_doc := json.unmarshal(resource.values.policy)
#     
#     # Check for sensitive actions without explicit deny
#     has_sensitive_actions_without_explicit_deny(policy_doc)
#     
#     msg := {
#         "control_id": "OPT-AWS-IAM-004",
#         "severity": "HIGH",
#         "resource": resource.address,
#         "message": "Policy allows sensitive actions without explicit deny statements for unauthorized use",
#         "remediation": "Add explicit deny statements for sensitive actions like iam:*, organizations:*, billing:*"
#     }
# }
# 
# has_sensitive_actions_without_explicit_deny(policy_doc) if {
#     statement := policy_doc.Statement[_]
#     statement.Effect == "Allow"
#     action := statement.Action[_]
#     is_sensitive_action(action)
#     not has_corresponding_deny(policy_doc, action)
# }
# 
# is_sensitive_action(action) if {
#     sensitive_prefixes := ["iam:", "organizations:", "billing:", "account:", "support:"]
#     prefix := sensitive_prefixes[_]
#     startswith(action, prefix)
# }
# 
# has_corresponding_deny(policy_doc, action) if {
#     statement := policy_doc.Statement[_]
#     statement.Effect == "Deny"
#     deny_action := statement.Action[_]
#     covers_action(deny_action, action)
# }
# 
# covers_action(deny_action, target_action) if {
#     deny_action == target_action
# }
# 
# covers_action(deny_action, target_action) if {
#     endswith(deny_action, "*")
#     prefix := substring(deny_action, 0, count(deny_action) - 1)
#     startswith(target_action, prefix)
# }