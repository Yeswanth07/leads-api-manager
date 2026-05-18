# ──────────────────────────────────────────────
# VPC
# ──────────────────────────────────────────────
resource "aws_vpc" "leads" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_prefix}-vpc"
  }
}

# ──────────────────────────────────────────────
# Public Subnet (Bastion + Nginx)
# ──────────────────────────────────────────────
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.leads.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_prefix}-public-subnet"
  }
}

# ──────────────────────────────────────────────
# Private Subnet (Consolidated Backend)
# ──────────────────────────────────────────────
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.leads.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "${var.project_prefix}-private-subnet"
  }
}

# ──────────────────────────────────────────────
# Internet Gateway
# ──────────────────────────────────────────────
resource "aws_internet_gateway" "leads" {
  vpc_id = aws_vpc.leads.id

  tags = {
    Name = "${var.project_prefix}-igw"
  }
}

# ──────────────────────────────────────────────
# Public Route Table
# ──────────────────────────────────────────────
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.leads.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.leads.id
  }

  tags = {
    Name = "${var.project_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ──────────────────────────────────────────────
# NAT Gateway (for Private Subnet outbound access)
# ──────────────────────────────────────────────
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.project_prefix}-nat-eip"
  }

  depends_on = [aws_internet_gateway.leads]
}

resource "aws_nat_gateway" "leads" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  tags = {
    Name = "${var.project_prefix}-nat-gw"
  }

  depends_on = [aws_internet_gateway.leads]
}

# ──────────────────────────────────────────────
# Private Route Table (routes outbound via NAT)
# ──────────────────────────────────────────────
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.leads.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.leads.id
  }

  tags = {
    Name = "${var.project_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}
