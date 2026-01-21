# CONTROL: AZ-LOG-006
# TITLE: Security Center standard tier should be enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SI-4, CIS-Azure:2.1, ISO-27001:A.12.6.1
# STATUS: ENABLED

package terraform.security.azure.logging.security_center

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_security_center_subscription_pricing"
    resource.values.tier == "Free"
    
    msg := {
        "control_id": "AZ-LOG-006",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Security Center is configured with Free tier instead of Standard tier",
        "remediation": "Set tier to 'Standard' to enable advanced security features"
    }
}

# CONTROL: AZ-LOG-007
# TITLE: Security Center auto-provisioning should be enabled
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:SI-4, CIS-Azure:2.2, ISO-27001:A.12.6.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_security_center_auto_provisioning"
    resource.values.auto_provision == "Off"
    
    msg := {
        "control_id": "AZ-LOG-007",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Security Center auto-provisioning is disabled",
        "remediation": "Set auto_provision to 'On' to automatically install monitoring agents"
    }
}

# CONTROL: AZ-LOG-008
# TITLE: Security Center should have default policy assignment
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:SI-4, CIS-Azure:2.15, ISO-27001:A.12.6.1
# STATUS: ENABLED

deny contains msg if {
    # Check if there's no Security Center workspace configuration
    not has_security_center_workspace
    
    msg := {
        "control_id": "AZ-LOG-008",
        "severity": "MEDIUM",
        "resource": "azurerm_security_center_workspace",
        "message": "Security Center workspace is not configured",
        "remediation": "Configure Security Center workspace using azurerm_security_center_workspace"
    }
}

has_security_center_workspace if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_security_center_workspace"
}

# CONTROL: AZ-LOG-009
# TITLE: Log Analytics workspace should have appropriate retention
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-4, CIS-Azure:5.1.3, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_log_analytics_workspace"
    resource.values.retention_in_days < 90
    
    msg := {
        "control_id": "AZ-LOG-009",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Log Analytics workspace retention is set to less than 90 days",
        "remediation": "Set retention_in_days to at least 90 days for compliance requirements"
    }
}

# CONTROL: AZ-LOG-010
# TITLE: Network Security Group flow logs should be retained for at least 90 days
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-4, CIS-Azure:6.5, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_watcher_flow_log"
    resource.values.retention_policy[0].enabled == true
    resource.values.retention_policy[0].days < 90
    
    msg := {
        "control_id": "AZ-LOG-010",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Network Watcher flow log retention is set to less than 90 days",
        "remediation": "Set retention_policy.days to at least 90 days"
    }
}