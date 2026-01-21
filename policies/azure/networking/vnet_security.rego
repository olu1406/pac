# CONTROL: AZ-NET-006
# TITLE: Virtual Networks must have Network Security Groups associated
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.6, ISO-27001:A.13.1.1
# STATUS: ENABLED

package terraform.security.azure.networking.vnet_security

import rego.v1

deny contains msg if {
    subnet := input.planned_values.root_module.resources[_]
    subnet.type == "azurerm_subnet"
    subnet.name != "GatewaySubnet"  # Gateway subnet doesn't support NSGs
    subnet.name != "AzureFirewallSubnet"  # Firewall subnet has special rules
    
    # Check if there's no NSG association for this subnet
    not has_nsg_association(subnet.values.id)
    
    msg := {
        "control_id": "AZ-NET-006",
        "severity": "HIGH",
        "resource": subnet.address,
        "message": "Subnet does not have a Network Security Group associated",
        "remediation": "Associate a Network Security Group with the subnet using azurerm_subnet_network_security_group_association"
    }
}

has_nsg_association(subnet_id) if {
    association := input.planned_values.root_module.resources[_]
    association.type == "azurerm_subnet_network_security_group_association"
    association.values.subnet_id == subnet_id
}

# CONTROL: AZ-NET-007
# TITLE: Virtual Networks should enable DDoS protection
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:SC-5, CIS-Azure:6.7, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_virtual_network"
    resource.values.ddos_protection_plan == null
    
    msg := {
        "control_id": "AZ-NET-007",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Virtual Network does not have DDoS protection enabled",
        "remediation": "Enable DDoS protection by configuring ddos_protection_plan"
    }
}

# CONTROL: AZ-NET-008
# TITLE: Virtual Network peering should not allow gateway transit from untrusted networks
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.8, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "azurerm_virtual_network_peering"
    resource.values.allow_gateway_transit == true
    resource.values.allow_forwarded_traffic == true
    
    msg := {
        "control_id": "AZ-NET-008",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Virtual Network peering allows gateway transit and forwarded traffic",
        "remediation": "Review and restrict gateway transit and forwarded traffic settings for security"
    }
}

# CONTROL: AZ-NET-009
# TITLE: Subnets should not have public IP addresses auto-assigned
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-4, CIS-Azure:6.9, ISO-27001:A.13.1.1
# STATUS: ENABLED

# Note: Azure doesn't have direct equivalent to AWS map_public_ip_on_launch
# This control checks for public IP associations that might indicate public exposure
deny contains msg if {
    nic := input.planned_values.root_module.resources[_]
    nic.type == "azurerm_network_interface"
    
    # Check if NIC has public IP associated
    ip_config := nic.values.ip_configuration[_]
    ip_config.public_ip_address_id != null
    
    msg := {
        "control_id": "AZ-NET-009",
        "severity": "MEDIUM",
        "resource": nic.address,
        "message": "Network interface has public IP address associated",
        "remediation": "Review if public IP is necessary; use private IPs and load balancers/gateways for public access"
    }
}

# CONTROL: AZ-NET-010
# TITLE: Network Watcher flow logs should be enabled
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-2, CIS-Azure:6.5, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    nsg := input.planned_values.root_module.resources[_]
    nsg.type == "azurerm_network_security_group"
    nsg_id := nsg.values.id
    
    # Check if there's no flow log for this NSG
    not has_flow_log(nsg_id)
    
    msg := {
        "control_id": "AZ-NET-010",
        "severity": "MEDIUM",
        "resource": nsg.address,
        "message": "Network Security Group does not have flow logs enabled",
        "remediation": "Enable Network Watcher flow logs using azurerm_network_watcher_flow_log"
    }
}

has_flow_log(nsg_id) if {
    flow_log := input.planned_values.root_module.resources[_]
    flow_log.type == "azurerm_network_watcher_flow_log"
    flow_log.values.network_security_group_id == nsg_id
}