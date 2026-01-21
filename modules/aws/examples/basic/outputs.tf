# Outputs for Basic AWS Landing Zone Example

# Organization outputs
output "organization_id" {
  description = "The organization ID"
  value       = module.organization.organization_id
}

output "organization_arn" {
  description = "The organization ARN"
  value       = module.organization.organization_arn
}

output "security_ou_id" {
  description = "The Security organizational unit ID"
  value       = module.organization.security_ou_id
}

output "cloudtrail_arn" {
  description = "ARN of the organization CloudTrail"
  value       = module.organization.cloudtrail_arn
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = module.organization.guardduty_detector_id
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

output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = module.networking.transit_gateway_id
}

output "flow_logs_s3_bucket" {
  description = "S3 bucket name for VPC Flow Logs"
  value       = module.networking.flow_logs_s3_bucket
}