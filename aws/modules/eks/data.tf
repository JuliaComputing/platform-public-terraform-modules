data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "tls_certificate" "cluster" {
  url = aws_eks_cluster._.identity[0].oidc[0].issuer
}

data "aws_ami" "bottlerocket" {
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["bottlerocket-aws-k8s-${var.kubernetes_version}-x86_64*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_eks_addon_version" "cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

data "aws_eks_addon_version" "efs_csi" {
  count = var.enable_efs_csi_driver ? 1 : 0

  addon_name         = "aws-efs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

locals {
  oidc_provider = replace(aws_eks_cluster._.identity[0].oidc[0].issuer, "https://", "")
  partition     = data.aws_partition.current.partition
  account_id    = data.aws_caller_identity.current.account_id
}
