# Outputs for AWS Networking Baseline Module

# Hub VPC outputs
output "hub_vpc_id" {
  description = "ID of the hub VPC"
  value       = aws_vpc.hub.id
}

output "hub_vpc_cidr" {
  description = "CIDR block of the hub VPC"
  value       = aws_vpc.hub.cidr_block
}

output "hub_public_subnet_ids" {
  description = "IDs of the hub VPC public subnets"
  value       = aws_subnet.hub_public[*].id
}

output "hub_private_subnet_ids" {
  description = "IDs of the hub VPC private subnets"
  value       = aws_subnet.hub_private[*].id
}

output "hub_internet_gateway_id" {
  description = "ID of the hub VPC internet gateway"
  value       = aws_internet_gateway.hub.id
}

output "hub_nat_gateway_ids" {
  description = "IDs of the hub VPC NAT gateways"
  value       = var.enable_nat_gateway ? aws_nat_gateway.hub[*].id : []
}

# Spoke VPC outputs
output "spoke_vpc_ids" {
  description = "IDs of the spoke VPCs"
  value       = aws_vpc.spoke[*].id
}

output "spoke_vpc_cidrs" {
  description = "CIDR blocks of the spoke VPCs"
  value       = aws_vpc.spoke[*].cidr_block
}

output "spoke_private_subnet_ids" {
  description = "IDs of the spoke VPC private subnets"
  value = {
    for i, vpc in var.spoke_vpcs : vpc.name => [
      for j in range(var.availability_zone_count) :
      aws_subnet.spoke_private[i * var.availability_zone_count + j].id
    ]
  }
}

# Transit Gateway outputs
output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway.main[0].id : null
}

output "transit_gateway_hub_attachment_id" {
  description = "ID of the hub VPC Transit Gateway attachment"
  value       = var.enable_transit_gateway ? aws_ec2_transit_gateway_vpc_attachment.hub[0].id : null
}

output "transit_gateway_spoke_attachment_ids" {
  description = "IDs of the spoke VPC Transit Gateway attachments"
  value = var.enable_transit_gateway ? {
    for i, vpc in var.spoke_vpcs : vpc.name => aws_ec2_transit_gateway_vpc_attachment.spoke[i].id
  } : {}
}

# Security Group outputs
output "hub_default_security_group_id" {
  description = "ID of the hub VPC default security group"
  value       = aws_security_group.hub_default.id
}

output "hub_management_security_group_id" {
  description = "ID of the hub VPC management security group"
  value       = aws_security_group.hub_management.id
}

output "hub_web_security_group_id" {
  description = "ID of the hub VPC web security group"
  value       = aws_security_group.hub_web.id
}

output "spoke_default_security_group_ids" {
  description = "IDs of the spoke VPC default security groups"
  value = {
    for i, vpc in var.spoke_vpcs : vpc.name => aws_security_group.spoke_default[i].id
  }
}

output "spoke_app_security_group_ids" {
  description = "IDs of the spoke VPC application security groups"
  value = {
    for i, vpc in var.spoke_vpcs : vpc.name => aws_security_group.spoke_app[i].id
  }
}

output "spoke_database_security_group_ids" {
  description = "IDs of the spoke VPC database security groups"
  value = {
    for i, vpc in var.spoke_vpcs : vpc.name => aws_security_group.spoke_database[i].id
  }
}

# Flow Logs outputs
output "flow_logs_s3_bucket" {
  description = "S3 bucket name for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_s3_bucket.flow_logs[0].bucket : null
}

output "flow_logs_kms_key_arn" {
  description = "KMS key ARN for VPC Flow Logs encryption"
  value       = var.enable_flow_logs ? aws_kms_key.flow_logs[0].arn : null
}

output "flow_logs_cloudwatch_log_group" {
  description = "CloudWatch log group name for VPC Flow Logs"
  value       = var.enable_flow_logs && var.flow_logs_destination == "cloudwatch" ? aws_cloudwatch_log_group.flow_logs[0].name : null
}

# Route Table outputs
output "hub_public_route_table_id" {
  description = "ID of the hub VPC public route table"
  value       = aws_route_table.hub_public.id
}

output "hub_private_route_table_ids" {
  description = "IDs of the hub VPC private route tables"
  value       = aws_route_table.hub_private[*].id
}

output "spoke_private_route_table_ids" {
  description = "IDs of the spoke VPC private route tables"
  value = {
    for i, vpc in var.spoke_vpcs : vpc.name => [
      for j in range(var.availability_zone_count) :
      aws_route_table.spoke_private[i * var.availability_zone_count + j].id
    ]
  }
}