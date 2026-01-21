# CONTROL: DATA-001
# TITLE: S3 buckets must have server-side encryption enabled
# SEVERITY: HIGH
# FRAMEWORKS: NIST-800-53:SC-28, CIS-AWS:2.1.1, ISO-27001:A.10.1.1
# STATUS: ENABLED

package terraform.security.aws.data.s3_encryption

import rego.v1

deny contains msg if {
    bucket := input.planned_values.root_module.resources[_]
    bucket.type == "aws_s3_bucket"
    bucket_name := bucket.values.bucket
    
    # Check if there's no server-side encryption configuration for this bucket
    not has_encryption_config(bucket_name)
    
    msg := {
        "control_id": "DATA-001",
        "severity": "HIGH",
        "resource": bucket.address,
        "message": "S3 bucket does not have server-side encryption enabled",
        "remediation": "Add aws_s3_bucket_server_side_encryption_configuration resource"
    }
}

has_encryption_config(bucket_name) if {
    encryption := input.planned_values.root_module.resources[_]
    encryption.type == "aws_s3_bucket_server_side_encryption_configuration"
    encryption.values.bucket == bucket_name
}

# CONTROL: DATA-002
# TITLE: S3 buckets must block public access
# SEVERITY: CRITICAL
# FRAMEWORKS: NIST-800-53:AC-3, CIS-AWS:2.1.5, ISO-27001:A.9.1.2
# STATUS: ENABLED

deny contains msg if {
    bucket := input.planned_values.root_module.resources[_]
    bucket.type == "aws_s3_bucket"
    bucket_name := bucket.values.bucket
    
    # Check if there's no public access block for this bucket
    not has_public_access_block(bucket_name)
    
    msg := {
        "control_id": "DATA-002",
        "severity": "CRITICAL",
        "resource": bucket.address,
        "message": "S3 bucket does not have public access blocked",
        "remediation": "Add aws_s3_bucket_public_access_block resource with all settings set to true"
    }
}

has_public_access_block(bucket_name) if {
    pab := input.planned_values.root_module.resources[_]
    pab.type == "aws_s3_bucket_public_access_block"
    pab.values.bucket == bucket_name
    pab.values.block_public_acls == true
    pab.values.block_public_policy == true
    pab.values.ignore_public_acls == true
    pab.values.restrict_public_buckets == true
}

# CONTROL: DATA-003
# TITLE: S3 buckets must have versioning enabled
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:CP-9, CIS-AWS:2.1.3, ISO-27001:A.12.3.1
# STATUS: ENABLED

deny contains msg if {
    bucket := input.planned_values.root_module.resources[_]
    bucket.type == "aws_s3_bucket"
    bucket_name := bucket.values.bucket
    
    # Check if there's no versioning configuration or it's disabled
    not has_versioning_enabled(bucket_name)
    
    msg := {
        "control_id": "DATA-003",
        "severity": "MEDIUM",
        "resource": bucket.address,
        "message": "S3 bucket does not have versioning enabled",
        "remediation": "Add aws_s3_bucket_versioning resource with status set to 'Enabled'"
    }
}

has_versioning_enabled(bucket_name) if {
    versioning := input.planned_values.root_module.resources[_]
    versioning.type == "aws_s3_bucket_versioning"
    versioning.values.bucket == bucket_name
    versioning.values.versioning_configuration[0].status == "Enabled"
}

# CONTROL: DATA-004
# TITLE: S3 buckets must have access logging enabled
# SEVERITY: MEDIUM
# FRAMEWORKS: NIST-800-53:AU-2, CIS-AWS:2.1.4, ISO-27001:A.12.4.1
# STATUS: ENABLED

deny contains msg if {
    bucket := input.planned_values.root_module.resources[_]
    bucket.type == "aws_s3_bucket"
    bucket_name := bucket.values.bucket
    
    # Check if there's no logging configuration for this bucket
    not has_logging_config(bucket_name)
    
    msg := {
        "control_id": "DATA-004",
        "severity": "MEDIUM",
        "resource": bucket.address,
        "message": "S3 bucket does not have access logging enabled",
        "remediation": "Add aws_s3_bucket_logging resource to enable access logging"
    }
}

has_logging_config(bucket_name) if {
    logging := input.planned_values.root_module.resources[_]
    logging.type == "aws_s3_bucket_logging"
    logging.values.bucket == bucket_name
}