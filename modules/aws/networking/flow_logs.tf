# VPC Flow Logs Configuration
# Implements comprehensive network traffic logging for security monitoring

# S3 bucket for VPC Flow Logs
resource "aws_s3_bucket" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  bucket        = "${var.name_prefix}-vpc-flow-logs-${random_id.flow_logs_suffix[0].hex}"
  force_destroy = false

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-vpc-flow-logs"
    Purpose = "VPCFlowLogs"
  })
}

# Generate random suffix for flow logs bucket
resource "random_id" "flow_logs_suffix" {
  count = var.enable_flow_logs ? 1 : 0

  byte_length = 4
}

# S3 bucket versioning for flow logs
resource "aws_s3_bucket_versioning" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 bucket encryption for flow logs
resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.flow_logs[0].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# S3 bucket public access block for flow logs
resource "aws_s3_bucket_public_access_block" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket lifecycle configuration
resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    id     = "flow_logs_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = var.flow_logs_retention_days
    }
  }
}

# KMS key for flow logs encryption
resource "aws_kms_key" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  description             = "KMS key for VPC Flow Logs encryption"
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
        Sid    = "Allow VPC Flow Logs"
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# KMS key alias for flow logs
resource "aws_kms_alias" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name          = "alias/${var.name_prefix}-vpc-flow-logs"
  target_key_id = aws_kms_key.flow_logs[0].key_id
}

# IAM role for VPC Flow Logs
resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for VPC Flow Logs to write to S3
resource "aws_iam_role_policy" "flow_logs_s3" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-s3-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.flow_logs[0].arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.flow_logs[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.flow_logs[0].arn
      }
    ]
  })
}

# VPC Flow Logs for hub VPC
resource "aws_flow_log" "hub_vpc" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  log_destination          = aws_s3_bucket.flow_logs[0].arn
  log_destination_type     = "s3"
  log_format              = var.flow_logs_format
  traffic_type            = "ALL"
  vpc_id                  = aws_vpc.hub.id
  max_aggregation_interval = 60

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-vpc-flow-logs"
  })
}

# VPC Flow Logs for spoke VPCs
resource "aws_flow_log" "spoke_vpc" {
  count = var.enable_flow_logs ? length(var.spoke_vpcs) : 0

  iam_role_arn             = aws_iam_role.flow_logs[0].arn
  log_destination          = aws_s3_bucket.flow_logs[0].arn
  log_destination_type     = "s3"
  log_format              = var.flow_logs_format
  traffic_type            = "ALL"
  vpc_id                  = aws_vpc.spoke[count.index].id
  max_aggregation_interval = 60

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-vpc-flow-logs"
  })
}

# CloudWatch Log Group for flow logs (alternative to S3)
resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_destination == "cloudwatch" ? 1 : 0

  name              = "/aws/vpc/flowlogs/${var.name_prefix}"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = aws_kms_key.flow_logs[0].arn

  tags = var.tags
}

# IAM role for CloudWatch flow logs
resource "aws_iam_role" "flow_logs_cloudwatch" {
  count = var.enable_flow_logs && var.flow_logs_destination == "cloudwatch" ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-cloudwatch-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM policy for CloudWatch flow logs
resource "aws_iam_role_policy" "flow_logs_cloudwatch" {
  count = var.enable_flow_logs && var.flow_logs_destination == "cloudwatch" ? 1 : 0

  name = "${var.name_prefix}-vpc-flow-logs-cloudwatch-policy"
  role = aws_iam_role.flow_logs_cloudwatch[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}
# VPC Flow Logs for hub VPC (CloudWatch destination)
resource "aws_flow_log" "hub_vpc_cloudwatch" {
  count = var.enable_flow_logs && var.flow_logs_destination == "cloudwatch" ? 1 : 0

  iam_role_arn         = aws_iam_role.flow_logs_cloudwatch[0].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  log_format          = var.flow_logs_format
  traffic_type        = "ALL"
  vpc_id              = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-vpc-flow-logs-cw"
  })
}

# VPC Flow Logs for spoke VPCs (CloudWatch destination)
resource "aws_flow_log" "spoke_vpc_cloudwatch" {
  count = var.enable_flow_logs && var.flow_logs_destination == "cloudwatch" ? length(var.spoke_vpcs) : 0

  iam_role_arn         = aws_iam_role.flow_logs_cloudwatch[0].arn
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  log_destination_type = "cloud-watch-logs"
  log_format          = var.flow_logs_format
  traffic_type        = "ALL"
  vpc_id              = aws_vpc.spoke[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-vpc-flow-logs-cw"
  })
}