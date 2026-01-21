# CONTROL: AZ-DATA-001
# TITLE: Storage Accounts must have encryption enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-Azure:3.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

package terraform.security.azure.data.storage_encryption

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_storage_account"
    resource.values.enable_https_traffic_only != true
    
    msg := {
        "control_id": "AZ-DATA-001",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Storage Account does not enforce HTTPS traffic only",
        "remediation": "Set enable_https_traffic_only to true"
    }
}

# CONTROL: AZ-DATA-002
# TITLE: Storage Accounts must not allow public blob access
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-3, CIS-Azure:3.7, ISO-27001:A.9.1.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_storage_account"
    resource.values.allow_nested_items_to_be_public == true
    
    msg := {
        "control_id": "AZ-DATA-002",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Storage Account allows public blob access",
        "remediation": "Set allow_nested_items_to_be_public to false"
    }
}

# CONTROL: AZ-DATA-003
# TITLE: Storage Account containers must not have public access
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-3, CIS-Azure:3.8, ISO-27001:A.9.1.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_storage_container"
    resource.values.container_access_type != "private"
    
    msg := {
        "control_id": "AZ-DATA-003",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Storage container allows public access",
        "remediation": "Set container_access_type to 'private'"
    }
}

# CONTROL: AZ-DATA-004
# TITLE: Storage Accounts should use customer-managed keys for encryption
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:SC-28, CIS-Azure:3.2, ISO-27001:A.10.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_storage_account"
    
    # Check if customer-managed key is not configured
    not resource.values.customer_managed_key
    
    msg := {
        "control_id": "AZ-DATA-004",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Storage Account is not using customer-managed keys for encryption",
        "remediation": "Configure customer_managed_key block to use Key Vault managed keys"
    }
}

# CONTROL: AZ-DATA-005
# TITLE: Storage Accounts should have minimum TLS version set to 1.2
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-8, CIS-Azure:3.15, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_storage_account"
    resource.values.min_tls_version != "TLS1_2"
    
    msg := {
        "control_id": "AZ-DATA-005",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Storage Account minimum TLS version is not set to 1.2",
        "remediation": "Set min_tls_version to 'TLS1_2'"
    }
}

# CONTROL: AZ-DATA-006
# TITLE: Storage Accounts should have soft delete enabled for blobs
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:CP-9, CIS-Azure:3.11, ISO-27001:A.12.3.1
# STATUS: ENABLED

deny contains msg if {
    storage := input.planned_values.root_module.resources[_]
    storage.type == "azurerm_storage_account"
    storage_name := storage.values.name
    
    # Check if there's no blob soft delete policy for this storage account
    not has_blob_soft_delete(storage_name)
    
    msg := {
        "control_id": "AZ-DATA-006",
        "severity": "MEDIUM",
        "resource": storage.address,
        "message": "Storage Account does not have soft delete enabled for blobs",
        "remediation": "Configure blob_properties with delete_retention_policy enabled"
    }
}

has_blob_soft_delete(storage_name) if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_storage_account"
    resource.values.name == storage_name
    resource.values.blob_properties[0].delete_retention_policy[0].days > 0
}