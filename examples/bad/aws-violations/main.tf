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

  default_tags {
    tags = var.tags
  }
}

# Generate random suffix for globally unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  name_prefix   = "${var.project_name}-${var.environment}"
  bucket_suffix = random_id.suffix.hex
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# VIOLATION NET-003: Default Security Group with rules
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # VIOLATION: Default security group should not have any rules
  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "${local.name_prefix}-default-sg"
  }
}

# VIOLATION NET-001 & NET-002: Security Group allowing SSH and RDP from anywhere
resource "aws_security_group" "insecure_web" {
  name_prefix = "${local.name_prefix}-insecure-web-"
  vpc_id      = aws_vpc.main.id
  description = "Insecure security group for demonstration"

  tags = {
    Name = "${local.name_prefix}-insecure-web-sg"
  }
}

# VIOLATION NET-001: SSH access from 0.0.0.0/0
resource "aws_security_group_rule" "ssh_from_anywhere" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # VIOLATION: Should be restricted
  security_group_id = aws_security_group.insecure_web.id
  description       = "SSH access from anywhere - INSECURE"
}

# VIOLATION NET-002: RDP access from 0.0.0.0/0
resource "aws_security_group_rule" "rdp_from_anywhere" {
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # VIOLATION: Should be restricted
  security_group_id = aws_security_group.insecure_web.id
  description       = "RDP access from anywhere - INSECURE"
}

# VIOLATION NET-004: Unrestricted outbound traffic
resource "aws_security_group_rule" "unrestricted_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]  # VIOLATION: Should be restricted
  security_group_id = aws_security_group.insecure_web.id
  description       = "Unrestricted outbound traffic - INSECURE"
}

# VIOLATION DATA-001 & DATA-002: S3 Bucket without encryption and public access
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "${var.s3_bucket_prefix}-insecure-${local.bucket_suffix}"

  tags = {
    Name = "${local.name_prefix}-insecure-bucket"
  }
}

# VIOLATION DATA-001: No server-side encryption configuration

# VIOLATION DATA-002: No public access block (allows public access)

# VIOLATION DATA-003: No versioning configuration

# VIOLATION DATA-004: No access logging configuration

# Additional S3 bucket to demonstrate public access violation
resource "aws_s3_bucket" "public_bucket" {
  bucket = "${var.s3_bucket_prefix}-public-${local.bucket_suffix}"

  tags = {
    Name = "${local.name_prefix}-public-bucket"
  }
}

# Explicitly allow public access (violates DATA-002)
resource "aws_s3_bucket_public_access_block" "public_bucket_bad" {
  bucket = aws_s3_bucket.public_bucket.id

  # VIOLATION DATA-002: Should all be true
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# VIOLATION IAM-004: Root user access key (simulated - cannot actually create)
# Note: This would be a violation if it were possible to create via Terraform
# resource "aws_iam_access_key" "root_key" {
#   user = "root"  # This would violate IAM-004
# }

# VIOLATION IAM-002: IAM User with inline policy
resource "aws_iam_user" "insecure_user" {
  name = "${local.name_prefix}-insecure-user"

  tags = {
    Name = "${local.name_prefix}-insecure-user"
  }
}

# VIOLATION IAM-002: Inline policy on user (should use managed policies)
resource "aws_iam_user_policy" "insecure_inline_policy" {
  name = "${local.name_prefix}-inline-policy"
  user = aws_iam_user.insecure_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "*"
      }
    ]
  })
}

# VIOLATION IAM-001: IAM Policy with wildcard actions on all resources
resource "aws_iam_policy" "wildcard_policy" {
  name_prefix = "${local.name_prefix}-wildcard-policy-"
  description = "Policy with wildcard actions - INSECURE"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"        # VIOLATION: Wildcard action
        Resource = "*"      # VIOLATION: All resources
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-wildcard-policy"
  }
}

# VIOLATION IAM-003: IAM Role with overly permissive trust policy
resource "aws_iam_role" "insecure_role" {
  name_prefix = "${local.name_prefix}-insecure-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = "*"  # VIOLATION: Should specify explicit principals
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-insecure-role"
  }
}

# Attach the wildcard policy to the role
resource "aws_iam_role_policy_attachment" "wildcard_attachment" {
  role       = aws_iam_role.insecure_role.name
  policy_arn = aws_iam_policy.wildcard_policy.arn
}

# Security Group with inline rules (also demonstrates violations)
resource "aws_security_group" "inline_rules" {
  name_prefix = "${local.name_prefix}-inline-"
  vpc_id      = aws_vpc.main.id
  description = "Security group with inline rules demonstrating violations"

  # VIOLATION NET-001: SSH from anywhere using inline rules
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # VIOLATION NET-002: RDP from anywhere using inline rules
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # VIOLATION NET-004: Unrestricted egress using inline rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-inline-sg"
  }
}