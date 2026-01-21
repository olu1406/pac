# CONTROL: AZ-IAM-001
# TITLE: Custom RBAC roles must not have wildcard permissions
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-6, CIS-Azure:1.21, ISO-27001:A.9.2.3
# STATUS: ENABLED

package terraform.security.azure.identity.rbac_policies

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_role_definition"
    permission := resource.values.permissions[_]
    permission.actions[_] == "*"
    
    msg := {
        "control_id": "AZ-IAM-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Custom RBAC role definition allows wildcard actions (*)",
        "remediation": "Replace wildcard actions with specific actions required for the role"
    }
}

# CONTROL: AZ-IAM-002
# TITLE: Role assignments must not grant Owner permissions at subscription scope
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.1, ISO-27001:A.9.2.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_role_assignment"
    resource.values.role_definition_name == "Owner"
    contains(resource.values.scope, "/subscriptions/")
    not contains(resource.values.scope, "/resourceGroups/")
    
    msg := {
        "control_id": "AZ-IAM-002",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Role assignment grants Owner permissions at subscription scope",
        "remediation": "Limit Owner role assignments to specific resource groups or use more restrictive roles"
    }
}

# CONTROL: AZ-IAM-003
# TITLE: Service principals must not have permanent credentials
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.2, ISO-27001:A.9.2.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azuread_application_password"
    
    # Check if password has no expiration or very long expiration
    not resource.values.end_date
    
    msg := {
        "control_id": "AZ-IAM-003",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Application password does not have an expiration date",
        "remediation": "Set end_date for application passwords to limit credential lifetime"
    }
}

# CONTROL: AZ-IAM-004
# TITLE: Guest users must be reviewed regularly
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.3, ISO-27001:A.9.2.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azuread_user"
    resource.values.user_type == "Guest"
    
    # This is a policy reminder rather than a technical control
    msg := {
        "control_id": "AZ-IAM-004",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Guest user detected - ensure regular access reviews are conducted",
        "remediation": "Implement regular access reviews for guest users and remove unused accounts"
    }
}

# CONTROL: AZ-IAM-005
# TITLE: Administrative accounts must require MFA
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:IA-2, CIS-Azure:1.1, ISO-27001:A.9.4.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_role_assignment"
    
    # Check for privileged roles
    privileged_roles := [
        "Owner",
        "Contributor", 
        "User Access Administrator",
        "Security Administrator",
        "Global Administrator"
    ]
    resource.values.role_definition_name in privileged_roles
    
    msg := {
        "control_id": "AZ-IAM-005",
        "severity": "HIGH",
        "resource": resource.address,
        "message": sprintf("Privileged role '%s' assigned - ensure MFA is required", [resource.values.role_definition_name]),
        "remediation": "Configure conditional access policies to require MFA for privileged roles"
    }
}