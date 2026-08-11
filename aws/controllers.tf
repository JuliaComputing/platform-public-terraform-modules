# Access entry for Karpenter-provisioned nodes.
#
# Declared at the root rather than inside the eks module: the karpenter module
# needs the cluster name, so eks cannot depend on karpenter without a cycle.
resource "aws_eks_access_entry" "karpenter_node" {
  count = var.create_karpenter_iam ? 1 : 0

  cluster_name  = module.eks.cluster_name
  principal_arn = module.karpenter[0].node_role_arn
  type          = "EC2_LINUX"

  tags = local.common_tags
}
