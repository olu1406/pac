# CONTROL: NET-005
# TITLE: VPC Flow Logs must be enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AU-2, CIS-AWS:2.9, ISO-27001:A.12.4.1
# STATUS: ENABLED

package terraform.security.aws.networking.vpc_security

import rego.v1

deny contains msg if {
    vpc := input.planned_values.root_module.resources[_]
    vpc.type == "aws_vpc"
    vpc_id := vpc.values.id
    
    # Check if there's no corresponding flow log for this VPC
    not has_flow_log(vpc_id)
    
    msg := {
        "control_id": "NET-005",
        "severity": "HIGH",
        "resource": vpc.address,
        "message": "VPC does not have Flow Logs enabled",
        "remediation": "Enable VPC Flow Logs using aws_flow_log resource"
    }
}

has_flow_log(vpc_id) if {
    flow_log := input.planned_values.root_module.resources[_]
    flow_log.type == "aws_flow_log"
    flow_log.values.vpc_id == vpc_id
}

# CONTROL: NET-006
# TITLE: VPC must not use default VPC
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:2.1, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_default_vpc"
    
    msg := {
        "control_id": "NET-006",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Default VPC is being used",
        "remediation": "Create custom VPC instead of using default VPC"
    }
}

# CONTROL: NET-007
# TITLE: Subnets should not auto-assign public IP addresses
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:2.2, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_subnet"
    resource.values.map_public_ip_on_launch == true
    
    msg := {
        "control_id": "NET-007",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Subnet is configured to auto-assign public IP addresses",
        "remediation": "Set map_public_ip_on_launch to false for private subnets"
    }
}

# CONTROL: NET-008
# TITLE: Network ACLs should not allow unrestricted access
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AC-4, CIS-AWS:4.5, ISO-27001:A.13.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_network_acl_rule"
    resource.values.rule_action == "allow"
    resource.values.cidr_block == "0.0.0.0/0"
    resource.values.from_port == 0
    resource.values.to_port == 65535
    
    msg := {
        "control_id": "NET-008",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "Network ACL rule allows unrestricted access from 0.0.0.0/0",
        "remediation": "Restrict Network ACL rules to specific ports and IP ranges"
    }
}