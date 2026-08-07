output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc._.id
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC"
  value       = aws_vpc._.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets. EKS nodes run here."
  value       = aws_subnet.private[*].id
}

output "subnet_ids" {
  description = "IDs of all subnets, public and private. Suitable for the EKS control plane, which benefits from both."
  value       = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
}

output "route_table_ids" {
  description = "IDs of all route tables, private and public"
  value       = concat(aws_route_table.private[*].id, [aws_route_table.public.id])
}

output "internet_gateway_id" {
  description = "ID of the internet gateway"
  value       = aws_internet_gateway._.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways in use, whether created by this module or supplied via nat_gateway_ids"
  value       = local.nat_gateway_ids
}

output "vpc_endpoint_security_group_id" {
  description = "ID of the security group attached to the interface VPC endpoints, or null when no interface endpoints are enabled"
  value       = length(aws_security_group.endpoints) > 0 ? aws_security_group.endpoints[0].id : null
}
