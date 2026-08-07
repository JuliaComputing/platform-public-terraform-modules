locals {
  # Interface endpoints in this module allow all actions from within the VPC;
  # access is constrained by the endpoint security group and by IAM on the
  # calling principal rather than by an endpoint policy.
  permissive_endpoint_policy = jsonencode({
    Statement = [
      {
        Action    = "*"
        Effect    = "Allow"
        Principal = "*"
        Resource  = "*"
      }
    ]
  })

  builtin_interface_endpoints = merge(
    var.enable_ecr_vpc_endpoint ? {
      "ecr-dkr" = {
        service_name        = "com.amazonaws.${var.region}.ecr.dkr"
        private_dns_enabled = true
      }
      "ecr-api" = {
        service_name        = "com.amazonaws.${var.region}.ecr.api"
        private_dns_enabled = true
      }
    } : {},
    var.enable_rds_vpc_endpoint ? {
      "rds" = {
        service_name        = "com.amazonaws.${var.region}.rds"
        private_dns_enabled = true
      }
    } : {},
    var.enable_s3_global_vpc_endpoint ? {
      "s3-global" = {
        service_name        = "com.amazonaws.s3-global.accesspoint"
        private_dns_enabled = false
      }
    } : {},
    var.enable_bedrock_vpc_endpoint ? {
      "bedrock-runtime" = {
        service_name        = "com.amazonaws.${var.region}.bedrock-runtime"
        private_dns_enabled = true
      }
    } : {},
  )

  interface_endpoints = merge(local.builtin_interface_endpoints, var.additional_interface_vpc_endpoints)
}

resource "aws_security_group" "endpoints" {
  count = length(local.interface_endpoints) > 0 ? 1 : 0

  name        = "${var.cluster_name}-vpc-endpoints"
  description = "Allows HTTPS from within the VPC to the interface VPC endpoints"
  vpc_id      = aws_vpc._.id

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc-endpoints"
  })

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    description = "Inbound HTTPS"
    cidr_blocks = local.vpc_endpoint_ingress_cidrs
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc._.id
  service_name        = each.value.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = each.value.private_dns_enabled
  security_group_ids  = [aws_security_group.endpoints[0].id]
  subnet_ids          = local.subnet_ids_unique_by_az
  policy              = local.permissive_endpoint_policy

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-${each.key}"
  })
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_vpc_endpoint ? 1 : 0

  vpc_id            = aws_vpc._.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  policy            = local.permissive_endpoint_policy

  tags = merge(var.tags, {
    Name = "eks-${var.cluster_name}-s3"
  })
}

resource "aws_vpc_endpoint_route_table_association" "s3_private" {
  count = var.enable_s3_vpc_endpoint ? length(var.private_subnet_cidrs) : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint_route_table_association" "s3_public" {
  count = var.enable_s3_vpc_endpoint ? 1 : 0

  vpc_endpoint_id = aws_vpc_endpoint.s3[0].id
  route_table_id  = aws_route_table.public.id
}
