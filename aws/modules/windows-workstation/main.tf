data "aws_caller_identity" "current" {}
# .name rather than .region: .region only exists in aws provider v6, and
# this module supports >= 5.0.0. .name works in both, deprecated in v6.
data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  name_slug            = var.resource_name_prefix != "" ? var.resource_name_prefix : replace(var.platform_hostname, ".", "-")
  launch_template_name = var.launch_template_name != "" ? var.launch_template_name : "winworkstation-${local.name_slug}"

  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_ami" "workstation" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["${var.ami_name}*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ami" "efs_samba" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = ["${var.efs_samba_ami_name}*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# --- Instance role ----------------------------------------------------------

# Shared by the workstations and their efs-samba sidecars. Both fetch their
# per-job secret and config from SSM parameters the platform writes under jr*.
resource "aws_iam_role" "instance" {
  name = "winworkstation.${local.name_slug}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "instance_ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# AmazonSSMManagedInstanceCore lets an instance read any parameter. A
# workstation is a user's machine, so confine it to the platform's job
# parameters.
resource "aws_iam_role_policy" "instance_ssm_parameters" {
  name = "job-parameters-only"
  role = aws_iam_role.instance.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect      = "Deny"
      Action      = ["ssm:GetParameter", "ssm:GetParameters"]
      NotResource = "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter/jr*"
    }]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "winworkstation.${local.name_slug}"
  role = aws_iam_role.instance.name
  tags = var.tags
}

# --- Security groups --------------------------------------------------------

resource "aws_security_group" "workstation" {
  name        = "winworkstation-${local.name_slug}"
  description = "Windows Workstation VMs: RDP from the cluster nodes guacd runs on"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "winworkstation-${local.name_slug}"
  })
}

resource "aws_vpc_security_group_ingress_rule" "workstation_rdp" {
  count = length(var.node_security_group_ids)

  security_group_id            = aws_security_group.workstation.id
  referenced_security_group_id = var.node_security_group_ids[count.index]
  from_port                    = 3389
  to_port                      = 3389
  ip_protocol                  = "tcp"
  description                  = "RDP from guacd"
}

resource "aws_vpc_security_group_egress_rule" "workstation" {
  security_group_id = aws_security_group.workstation.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "efs_samba" {
  name        = "winworkstation-${local.name_slug}-efs-samba"
  description = "Windows Workstation efs-samba sidecars: SMB from the workstations"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "winworkstation-${local.name_slug}-efs-samba"
  })
}

resource "aws_vpc_security_group_ingress_rule" "efs_samba_smb" {
  security_group_id            = aws_security_group.efs_samba.id
  referenced_security_group_id = aws_security_group.workstation.id
  from_port                    = 445
  to_port                      = 445
  ip_protocol                  = "tcp"
  description                  = "SMB from the workstations"
}

resource "aws_vpc_security_group_egress_rule" "efs_samba" {
  security_group_id = aws_security_group.efs_samba.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Launch templates -------------------------------------------------------

resource "aws_launch_template" "workstation" {
  name                   = local.launch_template_name
  image_id               = data.aws_ami.workstation.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  update_default_version = true

  instance_initiated_shutdown_behavior = "terminate"

  # IMDSv2 only, as on the cluster's own nodes. Accounts whose guardrails deny
  # RunInstances without it cannot launch workstations otherwise. Everything on
  # the instances that reads metadata (the AWS CLI, efs-utils, EC2Launch, the
  # SSM agent) supports session tokens.
  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    device_index                = 0
    security_groups             = [aws_security_group.workstation.id]
    subnet_id                   = var.subnet_id
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      # Encrypted so the platform can launch with hibernation enabled, which
      # requires an encrypted root volume.
      encrypted             = true
      delete_on_termination = true
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, var.instance_tags, {
      Name = local.launch_template_name
    })
  }

  tags = merge(var.tags, {
    Name = local.launch_template_name
  })
}

resource "aws_launch_template" "efs_samba" {
  name                   = "${local.launch_template_name}-efs-samba"
  image_id               = data.aws_ami.efs_samba.id
  instance_type          = var.efs_samba_instance_type
  key_name               = var.key_name
  update_default_version = true

  instance_initiated_shutdown_behavior = "terminate"

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 1
    http_tokens                 = "required"
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    device_index                = 0
    security_groups             = [aws_security_group.efs_samba.id]
    subnet_id                   = var.subnet_id
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      delete_on_termination = true
      volume_size           = 8
      volume_type           = "gp3"
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, var.instance_tags, var.efs_samba_instance_tags, {
      Name = "${local.launch_template_name}-efs-samba"
    })
  }

  # The platform looks the sidecar's launch template up by these tags, not by
  # name: an empty app (a workstation launched from a named template has no app
  # name) and a namespace equal to the platform hostname.
  tags = merge(var.tags, {
    Name                        = "${local.launch_template_name}-efs-samba"
    juliahub-winworkstation-app = ""
    juliahub-namespace          = var.platform_hostname
    juliarun-job-component      = "efs-samba"
  })
}

# --- Parameter Store tier ---------------------------------------------------

# The platform writes each workstation job's config and secret as SSM
# parameters without a tier, so they take the account's default. Under Standard
# a value over 4 KB fails, and the workstation never launches.
resource "aws_ssm_service_setting" "default_parameter_tier" {
  count = var.intelligent_parameter_tiering ? 1 : 0

  setting_id    = "arn:${local.partition}:ssm:${local.region}:${local.account_id}:servicesetting/ssm/parameter-store/default-parameter-tier"
  setting_value = "Intelligent-Tiering"
}

# --- Launcher permissions ---------------------------------------------------

resource "aws_iam_policy" "launcher" {
  name        = "winworkstation-launcher.${local.name_slug}"
  description = "Launching and managing Windows Workstation VMs for ${var.platform_hostname}"
  policy = templatefile("${path.module}/policies/launcher.json.tftpl", {
    partition         = local.partition
    region            = local.region
    account_id        = local.account_id
    instance_role_arn = aws_iam_role.instance.arn
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "launcher" {
  role       = var.launcher_role_name
  policy_arn = aws_iam_policy.launcher.arn
}
