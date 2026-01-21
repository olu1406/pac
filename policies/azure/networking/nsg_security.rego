# CONTROL: AZ-NET-001
# TITLE: Network Security Groups must not allow SSH from any source
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.1, ISO-27001:A.13.1.1
# STATUS: ENABLED

package terraform.security.azure.networking.nsg_security

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_security_rule"
    resource.values.access == "Allow"
    resource.values.direction == "Inbound"
    resource.values.destination_port_range == "22"
    resource.values.source_address_prefix == "*"
    
    msg := {
        "control_id": "AZ-NET-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Network Security Group rule allows SSH access from any source (*)",
        "remediation": "Restrict SSH access to specific IP ranges or use bastion hosts"
    }
}

# Also check for port ranges that include SSH
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_security_rule"
    resource.values.access == "Allow"
    resource.values.direction == "Inbound"
    resource.values.source_address_prefix == "*"
    
    # Check if port range includes SSH (22)
    port_range := resource.values.destination_port_range
    contains(port_range, "-")
    port_parts := split(port_range, "-")
    start_port := to_number(port_parts[0])
    end_port := to_number(port_parts[1])
    start_port <= 22
    end_port >= 22
    
    msg := {
        "control_id": "AZ-NET-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Network Security Group rule allows SSH access from any source (*) via port range",
        "remediation": "Restrict SSH access to specific IP ranges or use bastion hosts"
    }
}

# CONTROL: AZ-NET-002
# TITLE: Network Security Groups must not allow RDP from any source
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.2, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_security_rule"
    resource.values.access == "Allow"
    resource.values.direction == "Inbound"
    resource.values.destination_port_range == "3389"
    resource.values.source_address_prefix == "*"
    
    msg := {
        "control_id": "AZ-NET-002",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Network Security Group rule allows RDP access from any source (*)",
        "remediation": "Restrict RDP access to specific IP ranges or use bastion hosts"
    }
}

# CONTROL: AZ-NET-003
# TITLE: Network Security Groups must not allow unrestricted inbound access
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.3, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_security_rule"
    resource.values.access == "Allow"
    resource.values.direction == "Inbound"
    resource.values.destination_port_range == "*"
    resource.values.source_address_prefix == "*"
    
    msg := {
        "control_id": "AZ-NET-003",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Network Security Group rule allows unrestricted inbound access",
        "remediation": "Restrict inbound access to specific ports and source IP ranges"
    }
}

# CONTROL: AZ-NET-004
# TITLE: Default Network Security Group rules should be reviewed
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.4, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_security_group"
    
    # Check if NSG has no custom rules (only default rules)
    count(resource.values.security_rule) == 0
    
    msg := {
        "control_id": "AZ-NET-004",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Network Security Group has no custom security rules defined",
        "remediation": "Define explicit security rules instead of relying on default rules"
    }
}

# CONTROL: AZ-NET-005
# TITLE: Network Security Groups should deny high-risk ports
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.5, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_network_security_rule"
    resource.values.access == "Allow"
    resource.values.direction == "Inbound"
    resource.values.source_address_prefix == "*"
    
    # Check for high-risk ports
    high_risk_ports := ["23", "135", "445", "1433", "1521", "3306", "5432", "6379", "27017"]
    resource.values.destination_port_range in high_risk_ports
    
    msg := {
        "control_id": "AZ-NET-005",
        "severity": "HIGH",
        "resource": resource.address,
        "message": sprintf("Network Security Group allows access to high-risk port %s from any source", [resource.values.destination_port_range]),
        "remediation": "Restrict access to high-risk ports to specific source IP ranges"
    }
}