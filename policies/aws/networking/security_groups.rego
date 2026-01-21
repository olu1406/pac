# CONTROL: NET-001
# TITLE: No public SSH access from 0.0.0.0/0
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.1, ISO-27001:A.13.1.1
# STATUS: ENABLED

package terraform.security.aws.networking.security_groups

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    resource.values.type == "ingress"
    resource.values.from_port <= 22
    resource.values.to_port >= 22
    resource.values.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := {
        "control_id": "NET-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Security group allows SSH access from 0.0.0.0/0",
        "remediation": "Restrict SSH access to specific IP ranges or use bastion hosts"
    }
}

# Also check inline rules in security groups
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group"
    ingress := resource.values.ingress[_]
    ingress.from_port <= 22
    ingress.to_port >= 22
    ingress.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := {
        "control_id": "NET-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Security group allows SSH access from 0.0.0.0/0",
        "remediation": "Restrict SSH access to specific IP ranges or use bastion hosts"
    }
}

# CONTROL: NET-002
# TITLE: No public RDP access from 0.0.0.0/0
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.2, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    resource.values.type == "ingress"
    resource.values.from_port <= 3389
    resource.values.to_port >= 3389
    resource.values.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := {
        "control_id": "NET-002",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "Security group allows RDP access from 0.0.0.0/0",
        "remediation": "Restrict RDP access to specific IP ranges or use bastion hosts"
    }
}

# CONTROL: NET-003
# TITLE: Default security group should not allow any traffic
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.3, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_default_security_group"
    
    # Check if default security group has any ingress rules
    count(resource.values.ingress) > 0
    
    msg := {
        "control_id": "NET-003",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Default security group has ingress rules configured",
        "remediation": "Remove all ingress rules from default security group"
    }
}

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_default_security_group"
    
    # Check if default security group has any egress rules
    count(resource.values.egress) > 0
    
    msg := {
        "control_id": "NET-003",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Default security group has egress rules configured",
        "remediation": "Remove all egress rules from default security group"
    }
}

# CONTROL: NET-004
# TITLE: Security groups should not allow unrestricted outbound traffic
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.4, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    resource.values.type == "egress"
    resource.values.from_port == 0
    resource.values.to_port == 65535
    resource.values.cidr_blocks[_] == "0.0.0.0/0"
    
    msg := {
        "control_id": "NET-004",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Security group allows unrestricted outbound traffic to 0.0.0.0/0",
        "remediation": "Restrict outbound traffic to specific ports and destinations"
    }
}