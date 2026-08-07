output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster._.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster._.arn
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server"
  value       = aws_eks_cluster._.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane"
  value       = aws_eks_cluster._.version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster, for use in a kubeconfig"
  value       = aws_eks_cluster._.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "ID of the security group EKS creates for control plane to node communication"
  value       = aws_eks_cluster._.vpc_config[0].cluster_security_group_id
}

output "oidc_provider" {
  description = "OIDC issuer hostname and path, without the https:// scheme. Use this when building IRSA trust policy conditions."
  value       = local.oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for the cluster. Use this as the Federated principal in IRSA trust policies."
  value       = aws_iam_openid_connect_provider._.arn
}

output "node_role_arn" {
  description = "ARN of the IAM role attached to the critical node group instances"
  value       = aws_iam_role.node.arn
}

output "node_role_name" {
  description = "Name of the IAM role attached to the critical node group instances"
  value       = aws_iam_role.node.name
}

output "node_group_name" {
  description = "Name of the critical node group"
  value       = aws_eks_node_group.critical.node_group_name
}

output "critical_node_labels" {
  description = "Labels applied to the critical node group. The platform Helm chart's nodeSelectors must match these."
  value       = var.critical_node_labels
}
