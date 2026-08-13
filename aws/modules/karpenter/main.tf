# IAM and interruption handling for Karpenter.
#
# Karpenter itself is not installed here. AWS publishes no EKS managed add-on
# for it, so it is deployed by Helm from the upstream chart; this module creates
# the roles, instance profile, and interruption queue that chart needs.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
# .name rather than .region: .region only exists in aws provider v6, and
# this module supports >= 5.0.0. .name works in both, deprecated in v6.
data "aws_region" "current" {}

data "aws_eks_cluster" "_" {
  count = var.oidc_provider == "" ? 1 : 0
  name  = var.cluster_name
}

locals {
  # Looking the cluster up only works when it already exists. When it is created
  # in the same apply, the caller passes oidc_provider through instead.
  oidc_provider     = var.oidc_provider != "" ? var.oidc_provider : replace(data.aws_eks_cluster._[0].identity[0].oidc[0].issuer, "https://", "")
  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"

  partition  = data.aws_partition.current.partition
  account_id = data.aws_caller_identity.current.account_id

  node_role_name          = var.node_role_name == "" ? "${var.cluster_name}-karpenter-node" : var.node_role_name
  controller_role_name    = var.controller_role_name == "" ? "${var.cluster_name}-karpenter-controller" : var.controller_role_name
  interruption_queue_name = var.interruption_queue_name == "" ? "${var.cluster_name}-karpenter" : var.interruption_queue_name
}

# --- Node role --------------------------------------------------------------

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
  name               = local.node_role_name
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  policy_arn = each.value
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "node_additional" {
  for_each = toset(var.node_additional_managed_policies)

  policy_arn = each.value
  role       = aws_iam_role.node.name
}

resource "aws_iam_instance_profile" "node" {
  name = local.node_role_name
  role = aws_iam_role.node.name

  tags = var.tags
}

# --- Controller role --------------------------------------------------------

data "aws_iam_policy_document" "controller_assume_role" {
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

data "aws_iam_policy_document" "controller" {
  statement {
    sid = "ReadCapacityAndPricing"
    actions = [
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "pricing:GetProducts",
      "ssm:GetParameter",
    ]
    resources = ["*"]
  }

  statement {
    sid = "DescribeCluster"
    actions = [
      "eks:DescribeCluster",
    ]
    resources = ["arn:${local.partition}:eks:${data.aws_region.current.name}:${local.account_id}:cluster/${var.cluster_name}"]
  }

  statement {
    sid = "CreateFleet"
    actions = [
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:RunInstances",
    ]
    resources = ["*"]
  }

  # Karpenter tags everything it creates, and only at creation time.
  statement {
    sid       = "TagOnCreate"
    actions   = ["ec2:CreateTags"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances", "CreateFleet", "CreateLaunchTemplate"]
    }
  }

  # Teardown is limited to resources Karpenter itself provisioned for this
  # cluster, identified by the discovery tag it sets at creation.
  statement {
    sid = "TerminateAndCleanUpOwnedResources"
    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateTags",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned"]
    }
  }

  statement {
    sid       = "PassNodeRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.node.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid = "ManageNodeInstanceProfile"
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:GetInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile",
    ]
    resources = [
      "arn:${local.partition}:iam::${local.account_id}:instance-profile/${var.cluster_name}*",
    ]
  }

  statement {
    sid       = "ListInstanceProfiles"
    actions   = ["iam:ListInstanceProfiles", "iam:ListInstanceProfilesForRole"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.create_interruption_queue ? [1] : []

    content {
      sid = "InterruptionQueue"
      actions = [
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
        "sqs:GetQueueUrl",
        "sqs:ReceiveMessage",
      ]
      resources = [aws_sqs_queue.interruption[0].arn]
    }
  }
}

resource "aws_iam_role" "controller" {
  name               = local.controller_role_name
  assume_role_policy = data.aws_iam_policy_document.controller_assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy" "controller" {
  name   = "karpenter"
  role   = aws_iam_role.controller.id
  policy = data.aws_iam_policy_document.controller.json
}

# --- Interruption queue -----------------------------------------------------

resource "aws_sqs_queue" "interruption" {
  count = var.create_interruption_queue ? 1 : 0

  name                      = local.interruption_queue_name
  message_retention_seconds = var.interruption_queue_message_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = var.tags
}

data "aws_iam_policy_document" "interruption_queue" {
  count = var.create_interruption_queue ? 1 : 0

  statement {
    sid       = "AllowEventBridge"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.interruption[0].arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "sqs.amazonaws.com"]
    }
  }

  statement {
    sid       = "DenyUnencryptedTransport"
    effect    = "Deny"
    actions   = ["sqs:*"]
    resources = [aws_sqs_queue.interruption[0].arn]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "interruption" {
  count = var.create_interruption_queue ? 1 : 0

  queue_url = aws_sqs_queue.interruption[0].url
  policy    = data.aws_iam_policy_document.interruption_queue[0].json
}

locals {
  interruption_events = var.create_interruption_queue ? {
    spot_interruption = {
      description = "EC2 spot instance interruption warning"
      source      = "aws.ec2"
      detail_type = "EC2 Spot Instance Interruption Warning"
    }
    rebalance_recommendation = {
      description = "EC2 instance rebalance recommendation"
      source      = "aws.ec2"
      detail_type = "EC2 Instance Rebalance Recommendation"
    }
    scheduled_change = {
      description = "AWS health event affecting EC2 instances"
      source      = "aws.health"
      detail_type = "AWS Health Event"
    }
    instance_state_change = {
      description = "EC2 instance state change notification"
      source      = "aws.ec2"
      detail_type = "EC2 Instance State-change Notification"
    }
  } : {}
}

resource "aws_cloudwatch_event_rule" "interruption" {
  for_each = local.interruption_events

  name        = "${local.interruption_queue_name}-${each.key}"
  description = each.value.description

  event_pattern = jsonencode({
    source        = [each.value.source]
    "detail-type" = [each.value.detail_type]
  })

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "interruption" {
  for_each = local.interruption_events

  rule      = aws_cloudwatch_event_rule.interruption[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.interruption[0].arn
}
