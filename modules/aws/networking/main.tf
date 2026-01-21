# AWS Networking Baseline Module
# Implements secure VPC setup with hub-spoke topology and proper segmentation

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

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Hub VPC
resource "aws_vpc" "hub" {
  cidr_block           = var.hub_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-vpc"
    Type = "Hub"
  })
}

# Hub VPC Internet Gateway
resource "aws_internet_gateway" "hub" {
  vpc_id = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-igw"
  })
}

# Hub VPC public subnets
resource "aws_subnet" "hub_public" {
  count = var.availability_zone_count

  vpc_id                  = aws_vpc.hub.id
  cidr_block              = cidrsubnet(var.hub_vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-public-${count.index + 1}"
    Type = "Public"
  })
}

# Hub VPC private subnets
resource "aws_subnet" "hub_private" {
  count = var.availability_zone_count

  vpc_id            = aws_vpc.hub.id
  cidr_block        = cidrsubnet(var.hub_vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-private-${count.index + 1}"
    Type = "Private"
  })
}

# NAT Gateways for hub VPC
resource "aws_eip" "hub_nat" {
  count = var.enable_nat_gateway ? var.availability_zone_count : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-nat-eip-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.hub]
}

resource "aws_nat_gateway" "hub" {
  count = var.enable_nat_gateway ? var.availability_zone_count : 0

  allocation_id = aws_eip.hub_nat[count.index].id
  subnet_id     = aws_subnet.hub_public[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.hub]
}

# Hub VPC route tables
resource "aws_route_table" "hub_public" {
  vpc_id = aws_vpc.hub.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.hub.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-public-rt"
  })
}

resource "aws_route_table" "hub_private" {
  count = var.availability_zone_count

  vpc_id = aws_vpc.hub.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.hub[count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-private-rt-${count.index + 1}"
  })
}

# Route table associations for hub VPC
resource "aws_route_table_association" "hub_public" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.hub_public[count.index].id
  route_table_id = aws_route_table.hub_public.id
}

resource "aws_route_table_association" "hub_private" {
  count = var.availability_zone_count

  subnet_id      = aws_subnet.hub_private[count.index].id
  route_table_id = aws_route_table.hub_private[count.index].id
}

# Spoke VPCs
resource "aws_vpc" "spoke" {
  count = length(var.spoke_vpcs)

  cidr_block           = var.spoke_vpcs[count.index].cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-vpc"
    Type = "Spoke"
  })
}

# Spoke VPC private subnets
resource "aws_subnet" "spoke_private" {
  count = length(local.spoke_subnets)

  vpc_id            = aws_vpc.spoke[local.spoke_subnets[count.index].vpc_index].id
  cidr_block        = local.spoke_subnets[count.index].cidr_block
  availability_zone = data.aws_availability_zones.available.names[local.spoke_subnets[count.index].az_index]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[local.spoke_subnets[count.index].vpc_index].name}-private-${local.spoke_subnets[count.index].az_index + 1}"
    Type = "Private"
  })
}

# Local values for spoke subnet calculation
locals {
  spoke_subnets = flatten([
    for vpc_index, vpc in var.spoke_vpcs : [
      for az_index in range(var.availability_zone_count) : {
        vpc_index  = vpc_index
        az_index   = az_index
        cidr_block = cidrsubnet(vpc.cidr_block, 8, az_index)
      }
    ]
  ])
}

# Spoke VPC route tables
resource "aws_route_table" "spoke_private" {
  count = length(var.spoke_vpcs) * var.availability_zone_count

  vpc_id = aws_vpc.spoke[floor(count.index / var.availability_zone_count)].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[floor(count.index / var.availability_zone_count)].name}-private-rt-${(count.index % var.availability_zone_count) + 1}"
  })
}

# Route table associations for spoke VPCs
resource "aws_route_table_association" "spoke_private" {
  count = length(local.spoke_subnets)

  subnet_id      = aws_subnet.spoke_private[count.index].id
  route_table_id = aws_route_table.spoke_private[count.index].id
}