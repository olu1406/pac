output "vpc_id" {
  description = "ID of the insecure VPC"
  value       = aws_vpc.main.id
}

output "insecure_security_group_id" {
  description = "ID of the insecure security group"
  value       = aws_security_group.insecure_web.id
}

output "insecure_bucket_name" {
  description = "Name of the insecure S3 bucket"
  value       = aws_s3_bucket.insecure_bucket.id
}

output "public_bucket_name" {
  description = "Name of the public S3 bucket"
  value       = aws_s3_bucket.public_bucket.id
}

output "insecure_user_name" {
  description = "Name of the insecure IAM user"
  value       = aws_iam_user.insecure_user.name
}

output "wildcard_policy_arn" {
  description = "ARN of the wildcard IAM policy"
  value       = aws_iam_policy.wildcard_policy.arn
}

output "insecure_role_arn" {
  description = "ARN of the insecure IAM role"
  value       = aws_iam_role.insecure_role.arn
}

output "violations_summary" {
  description = "Summary of intentional security violations"
  value = {
    critical_violations = [
      "IAM-001: Wildcard actions on all resources",
      "IAM-003: Trust policy allows any principal (*)",
      "NET-001: SSH access from 0.0.0.0/0",
      "NET-002: RDP access from 0.0.0.0/0",
      "DATA-002: S3 bucket allows public access"
    ]
    high_violations = [
      "IAM-002: IAM user has inline policy",
      "NET-003: Default security group has rules",
      "NET-004: Unrestricted outbound traffic",
      "DATA-001: S3 bucket without encryption"
    ]
    medium_violations = [
      "DATA-003: S3 bucket without versioning",
      "DATA-004: S3 bucket without access logging"
    ]
    total_expected_violations = 11
  }
}