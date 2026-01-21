# CONTROL: DATA-005
# TITLE: EBS volumes must be encrypted
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-AWS:2.2.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

package terraform.security.aws.data.ebs_encryption

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ebs_volume"
    resource.values.encrypted != true
    
    msg := {
        "control_id": "DATA-005",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "EBS volume is not encrypted",
        "remediation": "Set encrypted to true for EBS volumes"
    }
}

# CONTROL: DATA-006
# TITLE: EBS snapshots must be encrypted
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-AWS:2.2.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ebs_snapshot"
    resource.values.encrypted != true
    
    msg := {
        "control_id": "DATA-006",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "EBS snapshot is not encrypted",
        "remediation": "Set encrypted to true for EBS snapshots"
    }
}

# CONTROL: DATA-007
# TITLE: RDS instances must be encrypted at rest
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-AWS:2.3.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_db_instance"
    resource.values.storage_encrypted != true
    
    msg := {
        "control_id": "DATA-007",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "RDS instance does not have storage encryption enabled",
        "remediation": "Set storage_encrypted to true for RDS instances"
    }
}

# CONTROL: DATA-008
# TITLE: RDS snapshots must be encrypted
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-AWS:2.3.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_db_snapshot"
    resource.values.storage_encrypted != true
    
    msg := {
        "control_id": "DATA-008",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "RDS snapshot is not encrypted",
        "remediation": "Set storage_encrypted to true for RDS snapshots"
    }
}