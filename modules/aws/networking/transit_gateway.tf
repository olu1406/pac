# Transit Gateway Configuration
# Implements hub-spoke connectivity with centralized routing

# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  description                     = "${var.name_prefix} Transit Gateway"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support               = "enable"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw"
  })
}

# Transit Gateway VPC Attachment - Hub
resource "aws_ec2_transit_gateway_vpc_attachment" "hub" {
  count = var.enable_transit_gateway ? 1 : 0

  subnet_ids         = aws_subnet.hub_private[*].id
  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = aws_vpc.hub.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-hub-tgw-attachment"
  })
}

# Transit Gateway VPC Attachments - Spokes
resource "aws_ec2_transit_gateway_vpc_attachment" "spoke" {
  count = var.enable_transit_gateway ? length(var.spoke_vpcs) : 0

  subnet_ids = [
    for i in range(var.availability_zone_count) :
    aws_subnet.spoke_private[count.index * var.availability_zone_count + i].id
  ]
  transit_gateway_id = aws_ec2_transit_gateway.main[0].id
  vpc_id             = aws_vpc.spoke[count.index].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.spoke_vpcs[count.index].name}-tgw-attachment"
  })
}

# Transit Gateway Route Table
resource "aws_ec2_transit_gateway_route_table" "main" {
  count = var.enable_transit_gateway ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.main[0].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-tgw-rt"
  })
}

# Routes from hub to spokes via Transit Gateway
resource "aws_route" "hub_to_spoke_via_tgw" {
  count = var.enable_transit_gateway ? length(var.spoke_vpcs) * var.availability_zone_count : 0

  route_table_id         = aws_route_table.hub_private[count.index % var.availability_zone_count].id
  destination_cidr_block = var.spoke_vpcs[floor(count.index / var.availability_zone_count)].cidr_block
  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.hub]
}

# Routes from spokes to hub via Transit Gateway
resource "aws_route" "spoke_to_hub_via_tgw" {
  count = var.enable_transit_gateway ? length(var.spoke_vpcs) * var.availability_zone_count : 0

  route_table_id         = aws_route_table.spoke_private[count.index].id
  destination_cidr_block = var.hub_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

# Routes between spokes via Transit Gateway
resource "aws_route" "spoke_to_spoke_via_tgw" {
  count = var.enable_transit_gateway ? length(local.spoke_to_spoke_routes) : 0

  route_table_id         = aws_route_table.spoke_private[local.spoke_to_spoke_routes[count.index].source_rt_index].id
  destination_cidr_block = local.spoke_to_spoke_routes[count.index].destination_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.main[0].id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.spoke]
}

# Local values for spoke-to-spoke routing
locals {
  spoke_to_spoke_routes = flatten([
    for source_vpc_index, source_vpc in var.spoke_vpcs : [
      for dest_vpc_index, dest_vpc in var.spoke_vpcs : [
        for az_index in range(var.availability_zone_count) : {
          source_rt_index   = source_vpc_index * var.availability_zone_count + az_index
          destination_cidr  = dest_vpc.cidr_block
        }
      ] if source_vpc_index != dest_vpc_index
    ]
  ])
}