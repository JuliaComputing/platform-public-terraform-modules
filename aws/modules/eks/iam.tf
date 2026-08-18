resource "aws_iam_openid_connect_provider" "_" {
  url = aws_eks_cluster._.identity[0].oidc[0].issuer

  client_id_list = [
    "sts.${var.region}.amazonaws.com",
    "sts.amazonaws.com",
  ]

  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# Trust policy for an IRSA role bound to a single Kubernetes service account.
data "aws_iam_policy_document" "irsa_assume_role" {
  for_each = {
    vpc_cni = "system:serviceaccount:kube-system:aws-node"
    ebs_csi = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
    efs_csi = "system:serviceaccount:kube-system:efs-csi-controller-sa"
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider._.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = [each.value]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# --- Cluster service role ---------------------------------------------------

data "aws_iam_policy_document" "cluster_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name                 = "eks-${var.cluster_name}-cluster-role"
  assume_role_policy   = data.aws_iam_policy_document.cluster_assume_role.json
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_eks_cluster" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_eks_vpc" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# --- vpc-cni addon ----------------------------------------------------------

resource "aws_iam_role" "vpc_cni" {
  name                 = "eks-${var.cluster_name}-vpc-cni"
  assume_role_policy   = data.aws_iam_policy_document.irsa_assume_role["vpc_cni"].json
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "vpc_cni" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.vpc_cni.name
}

# --- aws-ebs-csi-driver addon -----------------------------------------------

resource "aws_iam_role" "ebs_csi" {
  name                 = "eks-${var.cluster_name}-ebs-csi-driver"
  assume_role_policy   = data.aws_iam_policy_document.irsa_assume_role["ebs_csi"].json
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi.name
}

# --- aws-efs-csi-driver addon -----------------------------------------------

resource "aws_iam_role" "efs_csi" {
  count = var.enable_efs_csi_driver ? 1 : 0

  name                 = "eks-${var.cluster_name}-efs-csi-driver"
  assume_role_policy   = data.aws_iam_policy_document.irsa_assume_role["efs_csi"].json
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  count = var.enable_efs_csi_driver ? 1 : 0

  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi[0].name
}

# --- Node instance role -----------------------------------------------------

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name                 = "eks-${var.cluster_name}-node-instance-role"
  assume_role_policy   = data.aws_iam_policy_document.node_assume_role.json
  max_session_duration = 3600

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  policy_arn = each.value
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_additional" {
  for_each = toset(var.critical_node_additional_managed_policies)

  policy_arn = each.value
  role       = aws_iam_role.node.name
}
