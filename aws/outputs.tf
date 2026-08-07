# Networking outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# Cluster outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.eks.cluster_security_group_id
}

# IRSA outputs
output "oidc_provider" {
  description = "OIDC issuer hostname and path, for IRSA trust policy conditions"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider, for IRSA trust policies"
  value       = module.eks.oidc_provider_arn
}

output "node_role_arn" {
  description = "ARN of the node instance role"
  value       = module.eks.node_role_arn
}

# Convenience
output "kubeconfig_command" {
  description = "Command to add this cluster to your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    region             = var.region
    vpc_id             = module.vpc.vpc_id
    cluster_name       = module.eks.cluster_name
    cluster_version    = module.eks.cluster_version
    cluster_endpoint   = module.eks.cluster_endpoint
    private_subnet_ids = module.vpc.private_subnet_ids
    node_group_name    = module.eks.node_group_name
  }
}
