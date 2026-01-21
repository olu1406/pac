# GuardDuty Configuration
# Organization-wide threat detection and security monitoring

# Enable GuardDuty in the master account
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  datasources {
    s3_logs {
      enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = true
        }
      }
    }
  }

  tags = var.tags
}

# GuardDuty organization configuration
resource "aws_guardduty_organization_configuration" "main" {
  count = var.create_organization ? 1 : 0

  auto_enable = true
  detector_id = aws_guardduty_detector.main.id

  datasources {
    s3_logs {
      auto_enable = true
    }
    kubernetes {
      audit_logs {
        enable = true
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          auto_enable = true
        }
      }
    }
  }
}

# GuardDuty publishing destination for findings
resource "aws_guardduty_publishing_destination" "main" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  detector_id     = aws_guardduty_detector.main.id
  destination_arn = aws_s3_bucket.guardduty[0].arn
  kms_key_arn     = aws_kms_key.guardduty[0].arn

  depends_on = [aws_s3_bucket_policy.guardduty]
}

# S3 bucket for GuardDuty findings (optional)
resource "aws_s3_bucket" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  bucket        = "${var.organization_name}-guardduty-${random_id.guardduty_bucket_suffix[0].hex}"
  force_destroy = false

  tags = merge(var.tags, {
    Purpose = "GuardDutyFindings"
  })
}

# Generate random suffix for GuardDuty bucket name
resource "random_id" "guardduty_bucket_suffix" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  byte_length = 4
}

# S3 bucket versioning for GuardDuty
resource "aws_s3_bucket_versioning" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  bucket = aws_s3_bucket.guardduty[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption for GuardDuty
resource "aws_s3_bucket_server_side_encryption_configuration" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  bucket = aws_s3_bucket.guardduty[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.guardduty[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block for GuardDuty
resource "aws_s3_bucket_public_access_block" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  bucket = aws_s3_bucket.guardduty[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy for GuardDuty
resource "aws_s3_bucket_policy" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  bucket = aws_s3_bucket.guardduty[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Allow GuardDuty to use the getBucketLocation operation"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:GetBucketLocation"
        Resource = aws_s3_bucket.guardduty[0].arn
      },
      {
        Sid    = "Allow GuardDuty to upload objects to the bucket"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.guardduty[0].arn}/*"
      },
      {
        Sid    = "Deny unSecure connections"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.guardduty[0].arn,
          "${aws_s3_bucket.guardduty[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# KMS key for GuardDuty encryption
resource "aws_kms_key" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  description             = "KMS key for GuardDuty findings encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow GuardDuty to use the key"
        Effect = "Allow"
        Principal = {
          Service = "guardduty.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# KMS key alias for GuardDuty
resource "aws_kms_alias" "guardduty" {
  count = var.enable_guardduty_s3_export ? 1 : 0

  name          = "alias/${var.organization_name}-guardduty"
  target_key_id = aws_kms_key.guardduty[0].key_id
}

# GuardDuty threat intel set (optional)
resource "aws_guardduty_threatintelset" "main" {
  count = length(var.threat_intel_sets)

  activate    = true
  detector_id = aws_guardduty_detector.main.id
  format      = var.threat_intel_sets[count.index].format
  location    = var.threat_intel_sets[count.index].location
  name        = var.threat_intel_sets[count.index].name

  tags = var.tags
}

# GuardDuty IP set for trusted IPs (optional)
resource "aws_guardduty_ipset" "trusted" {
  count = length(var.trusted_ip_sets)

  activate    = true
  detector_id = aws_guardduty_detector.main.id
  format      = var.trusted_ip_sets[count.index].format
  location    = var.trusted_ip_sets[count.index].location
  name        = var.trusted_ip_sets[count.index].name

  tags = var.tags
}