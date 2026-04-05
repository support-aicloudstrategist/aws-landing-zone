# =============================================================================
# Networking Foundation - Shared VPC for Management Account
# =============================================================================
# COST NOTES:
# - VPC: Free
# - Subnets: Free
# - Internet Gateway: Free (data transfer charges apply)
# - NAT Gateway: ~$32/month + data processing (NOT created by default)
# - VPC Flow Logs to S3: Free (S3 storage cost only)
# - Transit Gateway: ~$36/month (NOT created by default — enable if needed)
#
# This module creates ONLY the free networking foundation.
# NAT Gateways and Transit Gateway are optional and flagged for cost.
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  az_count = 2
  az_names = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}

# -----------------------------------------------------------------------------
# VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = "${var.org_name}-management-vpc"
  })
}

# -----------------------------------------------------------------------------
# Subnets
# -----------------------------------------------------------------------------

# Public subnets (for bastion hosts, ALBs if needed)
resource "aws_subnet" "public" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = local.az_names[count.index]

  map_public_ip_on_launch = false # Security: no auto-assign public IPs

  tags = merge(var.tags, {
    Name = "${var.org_name}-public-${local.az_names[count.index]}"
    Tier = "public"
  })
}

# Private subnets (for workloads)
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = local.az_names[count.index]

  tags = merge(var.tags, {
    Name = "${var.org_name}-private-${local.az_names[count.index]}"
    Tier = "private"
  })
}

# -----------------------------------------------------------------------------
# Internet Gateway (Free)
# -----------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.org_name}-igw"
  })
}

# -----------------------------------------------------------------------------
# Route Tables
# -----------------------------------------------------------------------------

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.org_name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private route table (no internet access unless NAT Gateway is enabled)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.org_name}-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -----------------------------------------------------------------------------
# NAT Gateway (OPTIONAL - costs ~$32/month)
# Only created if var.enable_nat_gateway = true
# -----------------------------------------------------------------------------
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.org_name}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(var.tags, {
    Name    = "${var.org_name}-nat-gw"
    Warning = "COSTS ~$32/month"
  })
}

resource "aws_route" "private_nat" {
  count                  = var.enable_nat_gateway ? 1 : 0
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# -----------------------------------------------------------------------------
# VPC Flow Logs (to S3 — free, only S3 storage cost)
# -----------------------------------------------------------------------------
resource "aws_flow_log" "main" {
  log_destination      = var.flow_logs_bucket_arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.org_name}-vpc-flow-logs"
  })
}

# -----------------------------------------------------------------------------
# Default Security Group - Deny All (security best practice)
# -----------------------------------------------------------------------------
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress or egress rules = deny all traffic on default SG
  tags = merge(var.tags, {
    Name = "${var.org_name}-default-sg-deny-all"
  })
}

# -----------------------------------------------------------------------------
# Network ACL - Default with basic protections
# -----------------------------------------------------------------------------
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = merge(var.tags, {
    Name = "${var.org_name}-default-nacl"
  })
}
