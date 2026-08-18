locals {
  bootstrap_template      = "user-data-${lower(var.critical_node_bootstrap_type)}.template"
  critical_node_ami_id    = var.critical_node_ami_id == "" ? data.aws_ami.bottlerocket.id : var.critical_node_ami_id
  critical_nodegroup_name = replace("${var.cluster_name}-critical-nodegroup-${var.kubernetes_version}", ".", "-")
}

resource "aws_launch_template" "critical" {
  name          = local.critical_nodegroup_name
  instance_type = var.critical_node_instance_type
  image_id      = local.critical_node_ami_id

  block_device_mappings {
    device_name = "/dev/xvdb"

    ebs {
      iops        = 3000
      throughput  = 125
      volume_size = var.critical_node_volume_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  metadata_options {
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  dynamic "tag_specifications" {
    for_each = toset(["instance", "volume", "network-interface"])

    content {
      resource_type = tag_specifications.value
      tags = merge(
        var.tags,
        {
          Name                 = local.critical_nodegroup_name
          "eks:cluster-name"   = var.cluster_name
          "eks:nodegroup-name" = local.critical_nodegroup_name
        },
        var.launch_template_tags,
      )
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/${local.bootstrap_template}", {
    cluster_name = var.cluster_name
    api_server   = aws_eks_cluster._.endpoint
    cluster_cert = aws_eks_cluster._.certificate_authority[0].data
    service_cidr = aws_eks_cluster._.kubernetes_network_config[0].service_ipv4_cidr
  }))

  vpc_security_group_ids = [aws_eks_cluster._.vpc_config[0].cluster_security_group_id]

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "critical" {
  cluster_name    = aws_eks_cluster._.name
  node_group_name = local.critical_nodegroup_name
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.node_group_subnet_ids
  ami_type        = "CUSTOM"

  launch_template {
    id      = aws_launch_template.critical.id
    version = aws_launch_template.critical.latest_version
  }

  scaling_config {
    desired_size = var.critical_node_group_desired_size
    max_size     = var.critical_node_group_max_size
    min_size     = var.critical_node_group_min_size
  }

  labels = var.critical_node_labels

  dynamic "taint" {
    for_each = var.critical_node_taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
