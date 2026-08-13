# IRSA role for the AWS Load Balancer Controller.
#
# The controller itself is not installed here. AWS publishes no EKS managed
# add-on for it, so it is deployed by Helm from the upstream chart; this module
# creates the IAM role that chart's service account annotates.

variable "cluster_name" {
  description = "Name of the EKS cluster the controller runs in. Used to discover the cluster OIDC provider."
  type        = string
}

variable "oidc_provider" {
  description = <<-EOT
    OIDC issuer host and path for the cluster, without the https:// scheme, as
    the eks module's oidc_provider output gives it.

    Leave empty to look the cluster up by name. Supply it when the cluster is
    created in the same apply as this module, since the lookup then fails at
    plan time with "couldn't find resource".
  EOT
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace the controller is installed into. The upstream chart defaults to kube-system."
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Name of the controller's service account, used as the IRSA trust subject"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "role_name" {
  description = "Name of the IAM role. Leave empty to derive <cluster_name>-aws-load-balancer-controller."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the IAM role"
  type        = map(string)
  default     = {}
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster" "_" {
  count = var.oidc_provider == "" ? 1 : 0
  name  = var.cluster_name
}

locals {
  # Looking the cluster up only works when it already exists. When it is created
  # in the same apply, the caller passes oidc_provider through instead.
  oidc_provider     = var.oidc_provider != "" ? var.oidc_provider : replace(data.aws_eks_cluster._[0].identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"

  role_name = var.role_name == "" ? "${var.cluster_name}-aws-load-balancer-controller" : var.role_name
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "_" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

# Vendored from the upstream project so the permissions the controller needs
# stay pinned to a known release. See README for the source and how to refresh.
resource "aws_iam_policy" "_" {
  name        = local.role_name
  description = "Permissions for the AWS Load Balancer Controller on ${var.cluster_name}"
  policy      = file("${path.module}/iam_policy.json")

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "_" {
  role       = aws_iam_role._.name
  policy_arn = aws_iam_policy._.arn
}

output "iam_role_arn" {
  description = "ARN of the controller IRSA role. Set this as the eks.amazonaws.com/role-arn annotation on the controller's service account."
  value       = aws_iam_role._.arn
}

output "iam_role_name" {
  description = "Name of the controller IRSA role"
  value       = aws_iam_role._.name
}

output "service_account_name" {
  description = "Service account name the role trusts"
  value       = var.service_account_name
}

output "namespace" {
  description = "Namespace the role trusts the service account in"
  value       = var.namespace
}
