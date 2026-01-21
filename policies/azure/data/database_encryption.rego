# CONTROL: AZ-DATA-007
# TITLE: SQL Database must have Transparent Data Encryption enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-Azure:4.1.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

package terraform.security.azure.data.database_encryption

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_mssql_database"
    
    # Check if TDE is not explicitly enabled (it's enabled by default, but should be explicit)
    not has_tde_enabled(resource.values.name, resource.values.server_id)
    
    msg := {
        "control_id": "AZ-DATA-007",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "SQL Database does not have explicit Transparent Data Encryption configuration",
        "remediation": "Configure azurerm_mssql_database_extended_auditing_policy and ensure TDE is enabled"
    }
}

has_tde_enabled(db_name, server_id) if {
    # TDE is enabled by default in Azure SQL, but we check for explicit configuration
    tde := input.planned_values.root_module.resources[_]
    tde.type == "azurerm_mssql_database_transparent_data_encryption"
    tde.values.database_id == sprintf("%s/databases/%s", [server_id, db_name])
}

# CONTROL: AZ-DATA-008
# TITLE: SQL Server must have auditing enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AU-2, CIS-Azure:4.1.3, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    server := input.planned_values.root_module.resources[_]
    server.type == "azurerm_mssql_server"
    server_id := server.values.id
    
    # Check if there's no auditing policy for this server
    not has_server_auditing(server_id)
    
    msg := {
        "control_id": "AZ-DATA-008",
        "severity": "HIGH",
        "resource": server.address,
        "message": "SQL Server does not have auditing enabled",
        "remediation": "Configure azurerm_mssql_server_extended_auditing_policy for the SQL Server"
    }
}

has_server_auditing(server_id) if {
    auditing := input.planned_values.root_module.resources[_]
    auditing.type == "azurerm_mssql_server_extended_auditing_policy"
    auditing.values.server_id == server_id
}

# CONTROL: AZ-DATA-009
# TITLE: SQL Server must not allow Azure services access by default
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:4.2.1, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_mssql_firewall_rule"
    resource.values.start_ip_address == "0.0.0.0"
    resource.values.end_ip_address == "0.0.0.0"
    
    msg := {
        "control_id": "AZ-DATA-009",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "SQL Server firewall rule allows access from all Azure services",
        "remediation": "Remove the 0.0.0.0-0.0.0.0 firewall rule and configure specific IP ranges"
    }
}

# CONTROL: AZ-DATA-010
# TITLE: Key Vault keys must have expiration dates
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:SC-12, CIS-Azure:8.1, ISO-27001:A.10.1.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_key_vault_key"
    not resource.values.expiration_date
    
    msg := {
        "control_id": "AZ-DATA-010",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Key Vault key does not have an expiration date",
        "remediation": "Set expiration_date for Key Vault keys to ensure regular key rotation"
    }
}

# CONTROL: AZ-DATA-011
# TITLE: Key Vault secrets must have expiration dates
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:SC-12, CIS-Azure:8.2, ISO-27001:A.10.1.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_key_vault_secret"
    not resource.values.expiration_date
    
    msg := {
        "control_id": "AZ-DATA-011",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Key Vault secret does not have an expiration date",
        "remediation": "Set expiration_date for Key Vault secrets to ensure regular rotation"
    }
}

# CONTROL: AZ-DATA-012
# TITLE: Key Vault must have soft delete enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:CP-9, CIS-Azure:8.4, ISO-27001:A.12.3.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_key_vault"
    resource.values.soft_delete_retention_days < 7
    
    msg := {
        "control_id": "AZ-DATA-012",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Key Vault soft delete retention is less than 7 days",
        "remediation": "Set soft_delete_retention_days to at least 7 days"
    }
}