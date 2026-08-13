resource "aws_eks_cluster" "_" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = var.service_ipv4_cidr
  }

  vpc_config {
    endpoint_public_access = var.endpoint_public_access
    public_access_cidrs    = var.endpoint_public_access_cidrs
    subnet_ids             = var.control_plane_subnet_ids
  }

  access_config {
    authentication_mode                         = var.authentication_mode
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster_eks_cluster,
    aws_iam_role_policy_attachment.cluster_eks_vpc,
  ]
}

locals {
  addon_versions = {
    cni        = var.cni_version == "" ? data.aws_eks_addon_version.cni.version : var.cni_version
    coredns    = var.coredns_version == "" ? data.aws_eks_addon_version.coredns.version : var.coredns_version
    kube_proxy = var.kube_proxy_version == "" ? data.aws_eks_addon_version.kube_proxy.version : var.kube_proxy_version
    ebs_csi    = var.ebs_csi_version == "" ? data.aws_eks_addon_version.ebs_csi.version : var.ebs_csi_version
    efs_csi    = var.efs_csi_version == "" ? one(data.aws_eks_addon_version.efs_csi[*].version) : var.efs_csi_version
  }

  # CSI controllers are single-replica and pinned to the critical node group,
  # which is the only node group this module manages.
  csi_controller_config = {
    controller = {
      nodeSelector = var.addon_node_selector
      tolerations  = local.addon_tolerations
      replicaCount = 1
    }
    node = {}
  }

  # Addons must tolerate the taints on the critical node group they are pinned to.
  addon_tolerations = [
    for taint in var.critical_node_taints : {
      key      = taint.key
      value    = taint.value
      operator = "Equal"
      effect   = local.taint_effect_to_toleration[taint.effect]
    }
  ]

  taint_effect_to_toleration = {
    NO_SCHEDULE        = "NoSchedule"
    NO_EXECUTE         = "NoExecute"
    PREFER_NO_SCHEDULE = "PreferNoSchedule"
  }
}

resource "aws_eks_addon" "cni" {
  cluster_name                = aws_eks_cluster._.name
  addon_name                  = "vpc-cni"
  addon_version               = local.addon_versions.cni
  service_account_role_arn    = aws_iam_role.vpc_cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster._.name
  addon_name                  = "coredns"
  addon_version               = local.addon_versions.coredns
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  configuration_values = jsonencode({
    nodeSelector = var.addon_node_selector
    tolerations  = local.addon_tolerations
  })

  depends_on = [aws_eks_node_group.critical]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster._.name
  addon_name                  = "kube-proxy"
  addon_version               = local.addon_versions.kube_proxy
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster._.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = local.addon_versions.ebs_csi
  service_account_role_arn    = aws_iam_role.ebs_csi.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  configuration_values = jsonencode(merge(local.csi_controller_config, {
    defaultStorageClass = {
      enabled = var.create_default_storage_class
    }
  }))

  depends_on = [aws_eks_node_group.critical]
}

resource "aws_eks_addon" "efs_csi_driver" {
  count = var.enable_efs_csi_driver ? 1 : 0

  cluster_name                = aws_eks_cluster._.name
  addon_name                  = "aws-efs-csi-driver"
  addon_version               = local.addon_versions.efs_csi
  service_account_role_arn    = aws_iam_role.efs_csi[0].arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  configuration_values = jsonencode(local.csi_controller_config)

  depends_on = [aws_eks_node_group.critical]
}
