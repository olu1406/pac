# Outputs for AWS Organization and Account Baseline Module

# Organization outputs
output "organization_id" {
  description = "The organization ID"
  value       = var.create_organization ? aws_organizations_organization.main[0].id : null
}

output "organization_arn" {
  description = "The organization ARN"
  value       = var.create_organization ? aws_organizations_organization.main[0].arn : null
}

output "organization_root_id" {
  description = "The organization root ID"
  value       = var.create_organization ? aws_organizations_organization.main[0].roots[0].id : null
}

output "security_ou_id" {
  description = "The Security organizational unit ID"
  value       = var.create_organization ? aws_organizations_organizational_unit.security[0].id : null
}

output "workloads_ou_id" {
  description = "The Workloads organizational unit ID"
  value       = var.create_organization ? aws_organizations_organizational_unit.workloads[0].id : null
}

output "sandbox_ou_id" {
  description = "The Sandbox organizational unit ID"
  value       = var.create_organization ? aws_organizations_organizational_unit.sandbox[0].id : null
}

# IAM outputs
output "cross_account_security_role_arn" {
  description = "ARN of the cross-account security role"
  value       = var.security_account_id != "" ? aws_iam_role.cross_account_security[0].arn : null
}

output "break_glass_role_arn" {
  description = "ARN of the break glass emergency access role"
  value       = var.enable_break_glass_role ? aws_iam_role.break_glass[0].arn : null
}

output "cloudformation_execution_role_arn" {
  description = "ARN of the CloudFormation execution role"
  value       = aws_iam_role.cloudformation_execution.arn
}

# CloudTrail outputs
output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = aws_cloudtrail.organization.arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket name for CloudTrail logs"
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "cloudtrail_kms_key_arn" {
  description = "KMS key ARN for CloudTrail encryption"
  value       = aws_kms_key.cloudtrail.arn
}

# Config outputs
output "config_recorder_name" {
  description = "Name of the Config configuration recorder"
  value       = aws_config_configuration_recorder.main.name
}

output "config_delivery_channel_name" {
  description = "Name of the Config delivery channel"
  value       = aws_config_delivery_channel.main.name
}

output "config_s3_bucket" {
  description = "S3 bucket name for Config logs"
  value       = aws_s3_bucket.config.bucket
}

output "config_kms_key_arn" {
  description = "KMS key ARN for Config encryption"
  value       = aws_kms_key.config.arn
}

# GuardDuty outputs
output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.main.id
}

output "guardduty_s3_bucket" {
  description = "S3 bucket name for GuardDuty findings (if enabled)"
  value       = var.enable_guardduty_s3_export ? aws_s3_bucket.guardduty[0].bucket : null
}

output "guardduty_kms_key_arn" {
  description = "KMS key ARN for GuardDuty encryption (if S3 export enabled)"
  value       = var.enable_guardduty_s3_export ? aws_kms_key.guardduty[0].arn : null
}