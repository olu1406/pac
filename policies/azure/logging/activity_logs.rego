# CONTROL: AZ-LOG-001
# TITLE: Activity Log retention should be set to at least 90 days
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-4, CIS-Azure:5.1.1, ISO-27001:A.12.4.1
# STATUS: ENABLED

package terraform.security.azure.logging.activity_logs

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_monitor_log_profile"
    resource.values.retention_policy[0].enabled == true
    resource.values.retention_policy[0].days < 90
    
    msg := {
        "control_id": "AZ-LOG-001",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Activity Log retention is set to less than 90 days",
        "remediation": "Set retention_policy.days to at least 90 days"
    }
}

# CONTROL: AZ-LOG-002
# TITLE: Activity Logs should be exported to Log Analytics workspace
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AU-6, CIS-Azure:5.1.2, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    # Check if there's no diagnostic setting for activity logs
    not has_activity_log_diagnostic_setting
    
    msg := {
        "control_id": "AZ-LOG-002",
        "severity": "HIGH",
        "resource": "azurerm_monitor_diagnostic_setting",
        "message": "Activity Logs are not being exported to Log Analytics workspace",
        "remediation": "Configure diagnostic settings to export Activity Logs to Log Analytics workspace"
    }
}

has_activity_log_diagnostic_setting if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_monitor_diagnostic_setting"
    resource.values.target_resource_id == "/subscriptions/${subscription_id}"
    resource.values.log_analytics_workspace_id != null
}

# CONTROL: AZ-LOG-003
# TITLE: Security Center should have email notifications enabled
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:IR-6, CIS-Azure:2.13, ISO-27001:A.16.1.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_security_center_contact"
    resource.values.email == ""
    
    msg := {
        "control_id": "AZ-LOG-003",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Security Center contact email is not configured",
        "remediation": "Configure email address for Security Center notifications"
    }
}

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_security_center_contact"
    resource.values.alert_notifications == false
    
    msg := {
        "control_id": "AZ-LOG-003",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Security Center alert notifications are disabled",
        "remediation": "Enable alert_notifications for Security Center contact"
    }
}

# CONTROL: AZ-LOG-004
# TITLE: Key Vault should have diagnostic logging enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AU-2, CIS-Azure:5.1.5, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    kv := input.planned_values.root_module.resources[_]
    kv.type == "azurerm_key_vault"
    kv_id := kv.values.id
    
    # Check if there's no diagnostic setting for this Key Vault
    not has_keyvault_diagnostic_setting(kv_id)
    
    msg := {
        "control_id": "AZ-LOG-004",
        "severity": "HIGH",
        "resource": kv.address,
        "message": "Key Vault does not have diagnostic logging enabled",
        "remediation": "Configure diagnostic settings for Key Vault to enable audit logging"
    }
}

has_keyvault_diagnostic_setting(kv_id) if {
    diagnostic := input.planned_values.root_module.resources[_]
    diagnostic.type == "azurerm_monitor_diagnostic_setting"
    diagnostic.values.target_resource_id == kv_id
}

# CONTROL: AZ-LOG-005
# TITLE: Storage Account should have diagnostic logging enabled
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-2, CIS-Azure:5.1.6, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    storage := input.planned_values.root_module.resources[_]
    storage.type == "azurerm_storage_account"
    storage_id := storage.values.id
    
    # Check if there's no diagnostic setting for this Storage Account
    not has_storage_diagnostic_setting(storage_id)
    
    msg := {
        "control_id": "AZ-LOG-005",
        "severity": "MEDIUM",
        "resource": storage.address,
        "message": "Storage Account does not have diagnostic logging enabled",
        "remediation": "Configure diagnostic settings for Storage Account to enable access logging"
    }
}

has_storage_diagnostic_setting(storage_id) if {
    diagnostic := input.planned_values.root_module.resources[_]
    diagnostic.type == "azurerm_monitor_diagnostic_setting"
    diagnostic.values.target_resource_id == storage_id
}