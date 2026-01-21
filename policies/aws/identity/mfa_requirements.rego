# CONTROL: IAM-005
# TITLE: IAM users with console access must have MFA enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:IA-2, CIS-AWS:1.2, ISO-27001:A.9.4.2
# STATUS: ENABLED

package terraform.security.aws.identity.mfa_requirements

import rego.v1

# Check for IAM users with login profiles but no MFA device
deny contains msg if {
    login_profile := input.planned_values.root_module.resources[_]
    login_profile.type == "aws_iam_user_login_profile"
    user_name := login_profile.values.user
    
    # Check if there's no corresponding MFA device for this user
    not has_mfa_device(user_name)
    
    msg := {
        "control_id": "IAM-005",
        "severity": "HIGH",
        "resource": login_profile.address,
        "message": sprintf("IAM user '%s' has console access but no MFA device configured", [user_name]),
        "remediation": "Enable MFA for all IAM users with console access using aws_iam_virtual_mfa_device"
    }
}

has_mfa_device(user_name) if {
    mfa_device := input.planned_values.root_module.resources[_]
    mfa_device.type == "aws_iam_virtual_mfa_device"
    contains(mfa_device.values.virtual_mfa_device_name, user_name)
}

# CONTROL: IAM-006
# TITLE: Password policy must meet security requirements
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:IA-5, CIS-AWS:1.8, ISO-27001:A.9.4.3
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_account_password_policy"
    
    # Check minimum password length
    resource.values.minimum_password_length < 14
    
    msg := {
        "control_id": "IAM-006",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Password policy minimum length is less than 14 characters",
        "remediation": "Set minimum_password_length to at least 14 characters"
    }
}

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_account_password_policy"
    
    # Check password complexity requirements
    not resource.values.require_uppercase_characters
    
    msg := {
        "control_id": "IAM-006",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Password policy does not require uppercase characters",
        "remediation": "Set require_uppercase_characters to true"
    }
}

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_iam_account_password_policy"
    
    # Check password reuse prevention
    resource.values.password_reuse_prevention < 24
    
    msg := {
        "control_id": "IAM-006",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "Password policy allows reuse of recent passwords",
        "remediation": "Set password_reuse_prevention to at least 24"
    }
}