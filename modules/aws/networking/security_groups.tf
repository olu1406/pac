# Security Group Baselines
# Implements secure default security groups with least privilege

# Default security group for hub VPC
resource "aws_security_group" "hub_default" {
  name_prefix = "${var.name_prefix}-hub-default-"
  vpc_id      = aws_vpc.hub.id
  description = "Default security group for hub VPC with deny-all baseline"

  # No ingress rules - deny all inbound by default
  
  # Allow all outbound traffic (can be restricted per use case)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-default-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Management security group for hub VPC (SSH/RDP access)
resource "aws_security_group" "hub_management" {
  name_prefix = "${var.name_prefix}-hub-mgmt-"
  vpc_id      = aws_vpc.hub.id
  description = "Management access security group for hub VPC"

  # SSH access from management CIDR blocks
  dynamic "ingress" {
    for_each = var.management_cidrs
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "SSH access from management network"
    }
  }

  # RDP access from management CIDR blocks
  dynamic "ingress" {
    for_each = var.management_cidrs
    content {
      from_port   = 3389
      to_port     = 3389
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "RDP access from management network"
    }
  }

  # HTTPS access from management CIDR blocks
  dynamic "ingress" {
    for_each = var.management_cidrs
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "HTTPS access from management network"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-management-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Web tier security group for hub VPC
resource "aws_security_group" "hub_web" {
  name_prefix = "${var.name_prefix}-hub-web-"
  vpc_id      = aws_vpc.hub.id
  description = "Web tier security group for hub VPC"

  # HTTP access from anywhere (typically behind ALB)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-web-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Default security groups for spoke VPCs
resource "aws_security_group" "spoke_default" {
  count = length(var.spoke_vpcs)

  name_prefix = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-default-"
  vpc_id      = aws_vpc.spoke[count.index].id
  description = "Default security group for ${var.spoke_vpcs[count.index].name} spoke VPC"

  # Allow inbound from hub VPC
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.hub_vpc_cidr]
    description = "Allow all traffic from hub VPC"
  }

  # Allow inbound from same VPC
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Allow all traffic from same security group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-default-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Application security groups for spoke VPCs
resource "aws_security_group" "spoke_app" {
  count = length(var.spoke_vpcs)

  name_prefix = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-app-"
  vpc_id      = aws_vpc.spoke[count.index].id
  description = "Application security group for ${var.spoke_vpcs[count.index].name} spoke VPC"

  # Allow HTTP from hub web tier
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.hub_web.id]
    description     = "HTTP from hub web tier"
  }

  # Allow HTTPS from hub web tier
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.hub_web.id]
    description     = "HTTPS from hub web tier"
  }

  # Allow custom application ports from hub
  dynamic "ingress" {
    for_each = var.spoke_vpcs[count.index].allowed_ports != null ? var.spoke_vpcs[count.index].allowed_ports : []
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.hub_vpc_cidr]
      description = "Custom port ${ingress.value} from hub VPC"
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-app-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Database security group template (can be used in spoke VPCs)
resource "aws_security_group" "spoke_database" {
  count = length(var.spoke_vpcs)

  name_prefix = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-db-"
  vpc_id      = aws_vpc.spoke[count.index].id
  description = "Database security group for ${var.spoke_vpcs[count.index].name} spoke VPC"

  # MySQL/Aurora access from application tier
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.spoke_app[count.index].id]
    description     = "MySQL access from application tier"
  }

  # PostgreSQL access from application tier
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.spoke_app[count.index].id]
    description     = "PostgreSQL access from application tier"
  }

  # No outbound rules for database tier (most restrictive)
  
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-database-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}