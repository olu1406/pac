# Common Security Issues Example
# This file demonstrates security anti-patterns that are common across cloud providers
# DO NOT USE IN PRODUCTION - These are intentionally insecure configurations

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Generate random suffix
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  suffix = random_id.suffix.hex
}

# ANTI-PATTERN 1: Overprivileged IAM Policy
# Real-world impact: Allows lateral movement and privilege escalation
resource "aws_iam_policy" "god_mode" {
  name_prefix = "god-mode-policy-"
  description = "Policy that grants excessive permissions - DANGEROUS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"                    # All actions
        Resource = "*"                  # All resources
        Condition = {}                  # No conditions
      }
    ]
  })

  tags = {
    Name    = "god-mode-policy"
    Risk    = "CRITICAL"
    Purpose = "security-testing"
  }
}

# ANTI-PATTERN 2: Shared Administrative User
# Real-world impact: No accountability, credential sharing
resource "aws_iam_user" "shared_admin" {
  name = "shared-admin-${local.suffix}"
  path = "/"

  tags = {
    Name    = "shared-admin"
    Risk    = "HIGH"
    Purpose = "security-testing"
  }
}

resource "aws_iam_user_policy_attachment" "shared_admin" {
  user       = aws_iam_user.shared_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ANTI-PATTERN 3: Long-lived Access Keys
# Real-world impact: Credentials never rotated, high blast radius
resource "aws_iam_access_key" "long_lived" {
  user = aws_iam_user.shared_admin.name
  # No rotation policy, no expiration
}

# ANTI-PATTERN 4: VPC with No Security Controls
# Real-world impact: Flat network, no segmentation
resource "aws_vpc" "insecure_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "insecure-vpc-${local.suffix}"
    Risk = "HIGH"
  }
}

resource "aws_internet_gateway" "insecure_igw" {
  vpc_id = aws_vpc.insecure_vpc.id

  tags = {
    Name = "insecure-igw-${local.suffix}"
  }
}

# ANTI-PATTERN 5: Subnet with Auto-Assign Public IP
# Real-world impact: Resources automatically get public IPs
resource "aws_subnet" "public_by_default" {
  vpc_id                  = aws_vpc.insecure_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true  # DANGEROUS: Auto-assigns public IPs

  tags = {
    Name = "public-by-default-${local.suffix}"
    Risk = "MEDIUM"
  }
}

# ANTI-PATTERN 6: Security Group with "Allow All" Rules
# Real-world impact: No network access control
resource "aws_security_group" "allow_all" {
  name_prefix = "allow-all-"
  vpc_id      = aws_vpc.insecure_vpc.id
  description = "Security group that allows all traffic - DANGEROUS"

  # Allow all inbound traffic
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all TCP traffic from anywhere"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all UDP traffic from anywhere"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "allow-all-sg-${local.suffix}"
    Risk = "CRITICAL"
  }
}

# ANTI-PATTERN 7: Database Security Group Exposed to Internet
# Real-world impact: Direct database access from internet
resource "aws_security_group" "database_exposed" {
  name_prefix = "database-exposed-"
  vpc_id      = aws_vpc.insecure_vpc.id
  description = "Database security group exposed to internet - DANGEROUS"

  # MySQL from anywhere
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MySQL access from anywhere"
  }

  # PostgreSQL from anywhere
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "PostgreSQL access from anywhere"
  }

  # MongoDB from anywhere
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "MongoDB access from anywhere"
  }

  tags = {
    Name = "database-exposed-sg-${local.suffix}"
    Risk = "CRITICAL"
  }
}

# ANTI-PATTERN 8: S3 Bucket with Public Access and No Encryption
# Real-world impact: Data breaches, compliance violations
resource "aws_s3_bucket" "data_leak" {
  bucket = "data-leak-bucket-${local.suffix}"

  tags = {
    Name = "data-leak-bucket"
    Risk = "CRITICAL"
  }
}

# Explicitly allow public access
resource "aws_s3_bucket_public_access_block" "data_leak" {
  bucket = aws_s3_bucket.data_leak.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Public read policy
resource "aws_s3_bucket_policy" "data_leak" {
  bucket = aws_s3_bucket.data_leak.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.data_leak.arn}/*"
      }
    ]
  })
}

# ANTI-PATTERN 9: CloudTrail Disabled/Not Configured
# Real-world impact: No audit trail, compliance violations
# (Intentionally NOT creating CloudTrail to demonstrate the gap)

# ANTI-PATTERN 10: IAM Role with Overly Broad Trust Policy
# Real-world impact: Cross-account access abuse
resource "aws_iam_role" "overly_trusting" {
  name_prefix = "overly-trusting-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "*"  # Any AWS account can assume this role
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "*"  # Any AWS service can assume this role
        }
      }
    ]
  })

  tags = {
    Name = "overly-trusting-role"
    Risk = "CRITICAL"
  }
}

# Attach admin policy to the overly trusting role
resource "aws_iam_role_policy_attachment" "overly_trusting" {
  role       = aws_iam_role.overly_trusting.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ANTI-PATTERN 11: Default Security Group with Rules
# Real-world impact: Unintended network access
resource "aws_default_security_group" "default_with_rules" {
  vpc_id = aws_vpc.insecure_vpc.id

  # Default SG should be empty, but this adds rules
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "default-sg-with-rules"
    Risk = "HIGH"
  }
}

# Output the dangerous configurations for awareness
output "security_risks" {
  description = "Summary of security risks in this configuration"
  value = {
    critical_risks = [
      "IAM policy with wildcard permissions (*:*)",
      "S3 bucket with public read access",
      "Security group allowing all traffic from 0.0.0.0/0",
      "Database ports exposed to internet",
      "IAM role trusting any AWS account (*)"
    ]
    high_risks = [
      "Shared administrative user account",
      "Auto-assign public IP on subnet",
      "Default security group with rules",
      "Long-lived access keys without rotation"
    ]
    medium_risks = [
      "No CloudTrail logging configured",
      "No S3 encryption enabled",
      "No VPC Flow Logs enabled"
    ]
    remediation_note = "See examples/good/ for secure configuration patterns"
  }
}