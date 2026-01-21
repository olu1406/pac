# AWS Organization and Account Baseline Module
# Implements secure organization setup with IAM baseline, CloudTrail, Config, and GuardDuty

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

# AWS Organizations setup
resource "aws_organizations_organization" "main" {
  count = var.create_organization ? 1 : 0

  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com"
  ]

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY"
  ]

  feature_set = "ALL"
}

# Create organizational units
resource "aws_organizations_organizational_unit" "security" {
  count     = var.create_organization ? 1 : 0
  name      = "Security"
  parent_id = aws_organizations_organization.main[0].roots[0].id
}

resource "aws_organizations_organizational_unit" "workloads" {
  count     = var.create_organization ? 1 : 0
  name      = "Workloads"
  parent_id = aws_organizations_organization.main[0].roots[0].id
}

resource "aws_organizations_organizational_unit" "sandbox" {
  count     = var.create_organization ? 1 : 0
  name      = "Sandbox"
  parent_id = aws_organizations_organization.main[0].roots[0].id
}

# Service Control Policy for security baseline
resource "aws_organizations_policy" "security_baseline" {
  count = var.create_organization ? 1 : 0

  name        = "SecurityBaseline"
  description = "Baseline security controls for all accounts"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyRootUserActions"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:PrincipalType" = "Root"
          }
        }
      },
      {
        Sid    = "DenyCloudTrailDisable"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyConfigDisable"
        Effect = "Deny"
        Action = [
          "config:StopConfigurationRecorder",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach security baseline policy to root
resource "aws_organizations_policy_attachment" "security_baseline_root" {
  count = var.create_organization ? 1 : 0

  policy_id = aws_organizations_policy.security_baseline[0].id
  target_id = aws_organizations_organization.main[0].roots[0].id
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}