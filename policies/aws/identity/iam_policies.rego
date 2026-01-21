# CONTROL: IAM-001
# TITLE: IAM policies must not allow wildcard actions on all resources
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-6, CIS-AWS:1.16, ISO-27001:A.9.2.3
# STATUS: ENABLED

package terraform.security.aws.identity.iam_policies

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_policy"
    policy_doc := json.unmarshal(resource.values.policy)
    statement := policy_doc.Statement[_]
    
    # Check for wildcard actions on all resources
    statement.Effect == "Allow"
    statement.Action[_] == "*"
    statement.Resource[_] == "*"
    
    msg := {
        "control_id": "IAM-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "IAM policy allows wildcard actions (*) on all resources (*)",
        "remediation": "Replace wildcard actions with specific actions and limit resource scope"
    }
}

# CONTROL: IAM-002
# TITLE: IAM users must not have inline policies
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-AWS:1.15, ISO-27001:A.9.2.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_user_policy"
    
    msg := {
        "control_id": "IAM-002",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "IAM user has inline policy attached",
        "remediation": "Use managed policies or attach policies to groups instead of individual users"
    }
}

# CONTROL: IAM-003
# TITLE: IAM roles must have trust policy with specific principals
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-3, CIS-AWS:1.17, ISO-27001:A.9.1.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_role"
    trust_policy := json.unmarshal(resource.values.assume_role_policy)
    statement := trust_policy.Statement[_]
    
    # Check for overly permissive trust policies
    statement.Effect == "Allow"
    statement.Principal == "*"
    
    msg := {
        "control_id": "IAM-003",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "IAM role trust policy allows any principal (*)",
        "remediation": "Specify explicit principals in the trust policy"
    }
}

# CONTROL: IAM-004
# TITLE: Root access keys must not be created
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-2, CIS-AWS:1.4, ISO-27001:A.9.2.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_access_key"
    resource.values.user == "root"
    
    msg := {
        "control_id": "IAM-004",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Access key created for root user",
        "remediation": "Do not create access keys for the root user. Use IAM users with appropriate permissions instead"
    }
}