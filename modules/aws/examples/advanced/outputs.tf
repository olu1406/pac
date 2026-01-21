# Outputs for Advanced AWS Landing Zone Example

# Organization outputs
output "organization_id" {
  description = "The organization ID"
  value       = module.organization.organization_id
}

output "organization_arn" {
  description = "The organization ARN"
  value       = module.organization.organization_arn
}

output "organization_root_id" {
  description = "The organization root ID"
  value       = module.organization.organization_root_id
}

output "security_ou_id" {
  description = "The Security organizational unit ID"
  value       = module.organization.security_ou_id
}

output "workloads_ou_id" {
  description = "The Workloads organizational unit ID"
  value       = module.organization.workloads_ou_id
}

output "sandbox_ou_id" {
  description = "The Sandbox organizational unit ID"
  value       = module.organization.sandbox_ou_id
}

output "cross_account_security_role_arn" {
  description = "ARN of the cross-account security role"
  value       = module.organization.cross_account_security_role_arn
}

output "break_glass_role_arn" {
  description = "ARN of the break glass emergency access role"
  value       = module.organization.break_glass_role_arn
}

output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = module.organization.cloudtrail_arn
}

output "cloudtrail_s3_bucket" {
  description = "S3 bucket name for CloudTrail logs"
  value       = module.organization.cloudtrail_s3_bucket
}

output "config_recorder_name" {
  description = "Name of the Config configuration recorder"
  value       = module.organization.config_recorder_name
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = module.organization.guardduty_detector_id
}

output "guardduty_s3_bucket" {
  description = "S3 bucket name for GuardDuty findings"
  value       = module.organization.guardduty_s3_bucket
}

# Networking outputs
output "hub_vpc_id" {
  description = "ID of the hub VPC"
  value       = module.networking.hub_vpc_id
}

output "hub_vpc_cidr" {
  description = "CIDR block of the hub VPC"
  value       = module.networking.hub_vpc_cidr
}

output "spoke_vpc_ids" {
  description = "IDs of the spoke VPCs"
  value       = module.networking.spoke_vpc_ids
}

output "spoke_vpc_cidrs" {
  description = "CIDR blocks of the spoke VPCs"
  value       = module.networking.spoke_vpc_cidrs
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = module.networking.transit_gateway_id
}

output "flow_logs_s3_bucket" {
  description = "S3 bucket name for VPC Flow Logs"
  value       = module.networking.flow_logs_s3_bucket
}

output "flow_logs_kms_key_arn" {
  description = "KMS key ARN for VPC Flow Logs encryption"
  value       = module.networking.flow_logs_kms_key_arn
}