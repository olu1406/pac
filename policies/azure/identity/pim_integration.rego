# CONTROL: AZ-IAM-006
# TITLE: Privileged roles should use Privileged Identity Management (PIM)
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.15, ISO-27001:A.9.2.1
# STATUS: ENABLED

package terraform.security.azure.identity.pim_integration

import rego.v1

# Note: This control provides guidance as PIM is typically configured through Azure Portal
# Terraform support for PIM is limited, so this serves as a policy reminder

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_role_assignment"
    
    # Check for highly privileged roles that should use PIM
    pim_required_roles := [
        "Owner",
        "User Access Administrator", 
        "Security Administrator",
        "Privileged Role Administrator"
    ]
    resource.values.role_definition_name in pim_required_roles
    
    msg := {
        "control_id": "AZ-IAM-006",
        "severity": "HIGH",
        "resource": resource.address,
        "message": sprintf("Highly privileged role '%s' should be managed through PIM", [resource.values.role_definition_name]),
        "remediation": "Configure Privileged Identity Management for highly privileged role assignments"
    }
}

# CONTROL: AZ-IAM-007
# TITLE: Break-glass accounts must be monitored
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-2, CIS-Azure:1.16, ISO-27001:A.9.2.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azuread_user"
    
    # Detect potential break-glass accounts by naming convention
    break_glass_patterns := ["breakglass", "emergency", "break-glass", "bg-"]
    user_name := lower(resource.values.user_principal_name)
    
    some pattern in break_glass_patterns
    contains(user_name, pattern)
    
    msg := {
        "control_id": "AZ-IAM-007",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Break-glass account detected - ensure proper monitoring is configured",
        "remediation": "Configure alerts and monitoring for break-glass account usage"
    }
}

# CONTROL: AZ-IAM-008
# TITLE: Service principal credentials must have limited scope
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-6, CIS-Azure:1.23, ISO-27001:A.9.2.3
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_role_assignment"
    
    # Check if service principal has broad scope
    contains(resource.values.scope, "/subscriptions/")
    not contains(resource.values.scope, "/resourceGroups/")
    
    # Check if it's a service principal (not a user)
    startswith(resource.values.principal_id, "sp-")
    
    msg := {
        "control_id": "AZ-IAM-008",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Service principal has subscription-level permissions",
        "remediation": "Limit service principal permissions to specific resource groups when possible"
    }
}