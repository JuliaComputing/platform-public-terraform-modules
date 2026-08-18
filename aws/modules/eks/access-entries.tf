locals {
  # EC2 node roles need an access entry so their kubelets can register.
  # The node role created by this module, plus any supplied by the caller
  # (for example a Karpenter node role).
  node_role_arns = concat([aws_iam_role.node.arn], var.additional_node_role_arns)

  access_policy_associations = flatten([
    for idx, entry in var.access_entries : [
      for policy_arn in entry.access_policies : {
        key           = "${idx}-${policy_arn}"
        principal_arn = entry.principal_arn
        policy_arn    = policy_arn
      }
    ]
  ])
}

# Indexed rather than keyed by role arn: a caller may pass an arn for a role
# created in the same apply, which is unknown at plan time.
resource "aws_eks_access_entry" "nodes" {
  count = length(local.node_role_arns)

  cluster_name  = aws_eks_cluster._.name
  principal_arn = local.node_role_arns[count.index]
  type          = "EC2_LINUX"
}

resource "aws_eks_access_entry" "principals" {
  for_each = { for idx, entry in var.access_entries : idx => entry }

  cluster_name      = aws_eks_cluster._.name
  principal_arn     = each.value.principal_arn
  type              = "STANDARD"
  user_name         = each.value.username
  kubernetes_groups = each.value.groups

  tags = var.tags
}

resource "aws_eks_access_policy_association" "principals" {
  for_each = { for assoc in local.access_policy_associations : assoc.key => assoc }

  cluster_name  = aws_eks_cluster._.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.principals]
}
