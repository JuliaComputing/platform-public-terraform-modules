# Karpenter discovers the cluster security group by tag when launching nodes.
# The matching subnet tag is applied by the vpc module.
resource "aws_ec2_tag" "cluster_security_group_karpenter_discovery" {
  count = var.enable_karpenter_discovery_tag ? 1 : 0

  resource_id = aws_eks_cluster._.vpc_config[0].cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
