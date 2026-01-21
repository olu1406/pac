# IAM Baseline Configuration
# Implements least-privilege principles and secure IAM policies

# Password policy for IAM users
resource "aws_iam_account_password_policy" "strict" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_numbers               = true
  require_uppercase_characters   = true
  require_symbols               = true
  allow_users_to_change_password = true
  max_password_age              = 90
  password_reuse_prevention     = 24
  hard_expiry                   = false
}

# Cross-account access role for security account
resource "aws_iam_role" "cross_account_security" {
  count = var.security_account_id != "" ? 1 : 0

  name = "CrossAccountSecurityRole"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.security_account_id}:root"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

# Security role policy for read-only security operations
resource "aws_iam_role_policy" "security_readonly" {
  count = var.security_account_id != "" ? 1 : 0

  name = "SecurityReadOnlyPolicy"
  role = aws_iam_role.cross_account_security[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudtrail:Describe*",
          "cloudtrail:Get*",
          "cloudtrail:List*",
          "config:Describe*",
          "config:Get*",
          "config:List*",
          "guardduty:Describe*",
          "guardduty:Get*",
          "guardduty:List*",
          "securityhub:Describe*",
          "securityhub:Get*",
          "securityhub:List*",
          "iam:Get*",
          "iam:List*",
          "ec2:Describe*",
          "s3:GetBucket*",
          "s3:ListBucket*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Break glass role for emergency access
resource "aws_iam_role" "break_glass" {
  count = var.enable_break_glass_role ? 1 : 0

  name = "BreakGlassRole"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.break_glass_users
        }
        Condition = {
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "EmergencyAccess"
  })
}

# Break glass policy - administrative access with logging
resource "aws_iam_role_policy_attachment" "break_glass_admin" {
  count = var.enable_break_glass_role ? 1 : 0

  role       = aws_iam_role.break_glass[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# CloudFormation execution role for deployments
resource "aws_iam_role" "cloudformation_execution" {
  name = "CloudFormationExecutionRole"
  path = "/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cloudformation.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# CloudFormation execution policy
resource "aws_iam_role_policy" "cloudformation_execution" {
  name = "CloudFormationExecutionPolicy"
  role = aws_iam_role.cloudformation_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:*",
          "ec2:*",
          "s3:*",
          "cloudformation:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}