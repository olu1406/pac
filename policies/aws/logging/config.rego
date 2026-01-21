# CONTROL: LOG-006
# TITLE: AWS Config must be enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:CM-8, CIS-AWS:2.5, ISO-27001:A.12.5.1
# STATUS: ENABLED

package terraform.security.aws.logging.config

import rego.v1

deny contains msg if {
    # Check if AWS Config configuration recorder exists
    not has_config_recorder
    
    msg := {
        "control_id": "LOG-006",
        "severity": "HIGH",
        "resource": "aws_config_configuration_recorder",
        "message": "AWS Config configuration recorder is not enabled",
        "remediation": "Enable AWS Config configuration recorder to track resource configurations"
    }
}

has_config_recorder if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_config_configuration_recorder"
}

# CONTROL: LOG-007
# TITLE: AWS Config delivery channel must be configured
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:CM-8, CIS-AWS:2.5, ISO-27001:A.12.5.1
# STATUS: ENABLED

deny contains msg if {
    # Check if AWS Config delivery channel exists
    not has_delivery_channel
    
    msg := {
        "control_id": "LOG-007",
        "severity": "HIGH",
        "resource": "aws_config_delivery_channel",
        "message": "AWS Config delivery channel is not configured",
        "remediation": "Configure AWS Config delivery channel to deliver configuration snapshots"
    }
}

has_delivery_channel if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_config_delivery_channel"
}

# CONTROL: LOG-008
# TITLE: AWS Config recorder must record all resource types
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:CM-8, CIS-AWS:2.5, ISO-27001:A.12.5.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_config_configuration_recorder"
    
    # Check if recording group is configured to record all resources
    recording_group := resource.values.recording_group[0]
    recording_group.all_supported != true
    
    msg := {
        "control_id": "LOG-008",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "AWS Config is not configured to record all supported resource types",
        "remediation": "Set recording_group.all_supported to true"
    }
}

# CONTROL: LOG-009
# TITLE: AWS Config must include global resource types
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:CM-8, CIS-AWS:2.5, ISO-27001:A.12.5.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_config_configuration_recorder"
    
    # Check if recording group includes global resource types
    recording_group := resource.values.recording_group[0]
    recording_group.include_global_resource_types != true
    
    msg := {
        "control_id": "LOG-009",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "AWS Config is not configured to include global resource types",
        "remediation": "Set recording_group.include_global_resource_types to true"
    }
}