resource "aws_vpc" "_" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}"
  })
}

resource "aws_vpc_ipv4_cidr_block_association" "_" {
  for_each   = toset(var.additional_vpc_cidrs)
  vpc_id     = aws_vpc._.id
  cidr_block = each.value
}

locals {
  # Subnets are placed round-robin across the configured availability zones, so
  # that a two-subnet default lands in two distinct AZs as EKS requires.
  public_subnet_azs = [
    for idx in range(length(var.public_subnet_cidrs)) :
    var.availability_zones[idx % length(var.availability_zones)]
  ]

  private_subnet_azs = [
    for idx in range(length(var.private_subnet_cidrs)) :
    var.availability_zones[idx % length(var.availability_zones)]
  ]

  # Interface endpoints get one subnet per AZ; duplicate AZs are not permitted.
  subnet_ids_unique_by_az = values(zipmap(
    aws_subnet.private[*].availability_zone,
    aws_subnet.private[*].id
  ))

  vpc_endpoint_ingress_cidrs = length(var.vpc_endpoint_ingress_cidrs) > 0 ? var.vpc_endpoint_ingress_cidrs : [var.vpc_cidr]
}

resource "aws_subnet" "public" {
  count                               = length(var.public_subnet_cidrs)
  vpc_id                              = aws_vpc._.id
  cidr_block                          = var.public_subnet_cidrs[count.index]
  availability_zone                   = local.public_subnet_azs[count.index]
  map_public_ip_on_launch             = var.map_public_ip_on_launch
  private_dns_hostname_type_on_launch = "ip-name"

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-public-${local.public_subnet_azs[count.index]}"
    # Lets the AWS Load Balancer Controller discover subnets for internet-facing load balancers.
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "private" {
  count                               = length(var.private_subnet_cidrs)
  vpc_id                              = aws_vpc._.id
  cidr_block                          = var.private_subnet_cidrs[count.index]
  availability_zone                   = local.private_subnet_azs[count.index]
  private_dns_hostname_type_on_launch = "ip-name"

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-private-${local.private_subnet_azs[count.index]}"
    # Lets the AWS Load Balancer Controller discover subnets for internal load balancers.
    "kubernetes.io/role/internal-elb" = "1"
    # Lets Karpenter discover subnets to launch nodes into.
    "karpenter.sh/discovery" = var.cluster_name
  })
}

data "aws_vpc_dhcp_options" "_" {
  count = var.dhcp_option_domain == "" ? 0 : 1

  filter {
    name   = "key"
    values = ["domain-name"]
  }

  filter {
    name   = "value"
    values = [var.dhcp_option_domain]
  }
}

resource "aws_vpc_dhcp_options_association" "_" {
  count           = var.dhcp_option_domain == "" ? 0 : 1
  vpc_id          = aws_vpc._.id
  dhcp_options_id = data.aws_vpc_dhcp_options._[0].id
}

resource "aws_internet_gateway" "_" {
  vpc_id = aws_vpc._.id

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc._.id

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-public"
  })
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway._.id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count  = length(var.nat_gateway_ids) > 0 ? 0 : length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-nat-gateway-${local.public_subnet_azs[count.index]}"
  })
}

resource "aws_nat_gateway" "_" {
  count         = length(var.nat_gateway_ids) > 0 ? 0 : length(var.public_subnet_cidrs)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-nat-gateway-${local.public_subnet_azs[count.index]}"
  })

  depends_on = [aws_internet_gateway._]
}

resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc._.id

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-private-${local.private_subnet_azs[count.index]}"
  })
}

locals {
  nat_gateway_ids = length(var.nat_gateway_ids) > 0 ? var.nat_gateway_ids : aws_nat_gateway._[*].id
}

resource "aws_route" "private_default" {
  count                  = length(var.private_subnet_cidrs)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  # Prefer the NAT gateway in the same AZ; fall back to the last one when fewer
  # NAT gateways than private subnets are available.
  nat_gateway_id = local.nat_gateway_ids[min(count.index, length(local.nat_gateway_ids) - 1)]
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
