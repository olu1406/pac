# CONTROL: LOG-001
# TITLE: CloudTrail must be enabled in all regions
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AU-2, CIS-AWS:2.1, ISO-27001:A.12.4.1
# STATUS: ENABLED

package terraform.security.aws.logging.cloudtrail

import rego.v1

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudtrail"
    resource.values.is_multi_region_trail != true
    
    msg := {
        "control_id": "LOG-001",
        "severity": "CRITICAL",
        "resource": resource.address,
        "message": "CloudTrail is not configured for multi-region logging",
        "remediation": "Set is_multi_region_trail to true"
    }
}

# CONTROL: LOG-002
# TITLE: CloudTrail log file validation must be enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:AU-9, CIS-AWS:2.2, ISO-27001:A.12.4.2
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudtrail"
    resource.values.enable_log_file_validation != true
    
    msg := {
        "control_id": "LOG-002",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "CloudTrail log file validation is not enabled",
        "remediation": "Set enable_log_file_validation to true"
    }
}

# CONTROL: LOG-003
# TITLE: CloudTrail logs must be encrypted at rest
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-AWS:2.7, ISO-27001:A.10.1.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudtrail"
    not resource.values.kms_key_id
    
    msg := {
        "control_id": "LOG-003",
        "severity": "HIGH",
        "resource": resource.address,
        "message": "CloudTrail logs are not encrypted with KMS",
        "remediation": "Configure kms_key_id to encrypt CloudTrail logs"
    }
}

# CONTROL: LOG-004
# TITLE: CloudTrail must include management events
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-2, CIS-AWS:2.3, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudtrail"
    resource.values.include_global_service_events != true
    
    msg := {
        "control_id": "LOG-004",
        "severity": "MEDIUM",
        "resource": resource.address,
        "message": "CloudTrail does not include global service events",
        "remediation": "Set include_global_service_events to true"
    }
}

# CONTROL: LOG-005
# TITLE: CloudTrail S3 bucket must not be publicly accessible
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-3, CIS-AWS:2.3, ISO-27001:A.9.1.2
# STATUS: ENABLED

deny contains msg if {
    cloudtrail := input.planned_values.root_module.resources[_]
    cloudtrail.type == "aws_cloudtrail"
    bucket_name := cloudtrail.values.s3_bucket_name
    
    # Check if the S3 bucket allows public access
    bucket_has_public_access(bucket_name)
    
    msg := {
        "control_id": "LOG-005",
        "severity": "CRITICAL",
        "resource": cloudtrail.address,
        "message": "CloudTrail S3 bucket allows public access",
        "remediation": "Configure S3 bucket to block public access and use proper IAM policies"
    }
}

bucket_has_public_access(bucket_name) if {
    bucket := input.planned_values.root_module.resources[_]
    bucket.type == "aws_s3_bucket"
    bucket.values.bucket == bucket_name
    
    # Check for public ACL
    bucket_acl := input.planned_values.root_module.resources[_]
    bucket_acl.type == "aws_s3_bucket_acl"
    bucket_acl.values.bucket == bucket_name
    bucket_acl.values.acl == "public-read"
}