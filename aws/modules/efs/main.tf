locals {
  # The config directory is written by every platform component under its own
  # user, so its access point does not pin a POSIX identity. Userdata is mounted
  # into job containers, which run as a fixed uid/gid.
  purpose_defaults = {
    config = {
      path        = "/config"
      uid         = null
      gid         = null
      owner_uid   = 0
      owner_gid   = 0
      permissions = "0777"
    }
    userdata = {
      path        = "/data"
      uid         = 8000
      gid         = 8000
      owner_uid   = 8000
      owner_gid   = 8000
      permissions = "0777"
    }
  }

  defaults = local.purpose_defaults[var.purpose]

  access_point_path = var.access_point_path == "" ? local.defaults.path : var.access_point_path
  access_point_uid  = var.access_point_uid == null ? local.defaults.uid : var.access_point_uid
  access_point_gid  = var.access_point_gid == null ? local.defaults.gid : var.access_point_gid

  # A POSIX user is only pinned when both ids are known.
  pin_posix_user = local.access_point_uid != null && local.access_point_gid != null

  owner_uid = local.access_point_uid == null ? local.defaults.owner_uid : local.access_point_uid
  owner_gid = local.access_point_gid == null ? local.defaults.owner_gid : local.access_point_gid

  tiering_enabled = var.transition_to_ia != "none"
  restrict_mount  = length(var.restrict_mount_to_role_arns) > 0

  # A mount authenticates as an STS session, so aws:PrincipalArn is the
  # assumed-role form (arn:aws:sts::<acct>:assumed-role/<role>/<session>)
  # rather than the iam role arn the caller passes. Comparing against the role
  # arn alone never matches, so the deny below would fire against the very
  # roles the allow permits. Both forms are matched, with a wildcard for the
  # session name.
  mount_principal_arn_patterns = flatten([
    for arn in var.restrict_mount_to_role_arns : [
      arn,
      "${replace(replace(arn, ":iam::", ":sts::"), ":role/", ":assumed-role/")}/*",
    ]
  ])

  # At most one mount target per availability zone is permitted. The AZ of each
  # subnet is only known after apply, so rather than deduplicating here (which
  # would make the resource count unknown at plan time) a mount target is
  # declared per supplied subnet. Callers pass one subnet per AZ.
  mount_target_subnet_ids = var.subnet_ids
}

resource "aws_efs_file_system" "_" {
  encrypted  = var.encrypted
  kms_key_id = var.kms_key_id == "" ? null : var.kms_key_id

  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null
  performance_mode                = var.performance_mode

  dynamic "lifecycle_policy" {
    for_each = local.tiering_enabled ? [1] : []

    content {
      transition_to_ia = var.transition_to_ia
    }
  }

  dynamic "lifecycle_policy" {
    for_each = local.tiering_enabled ? [1] : []

    content {
      transition_to_primary_storage_class = var.transition_to_primary_storage_class
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.purpose}"
  })
}

resource "aws_efs_backup_policy" "_" {
  count = var.enable_backup_policy ? 1 : 0

  file_system_id = aws_efs_file_system._.id

  backup_policy {
    status = "ENABLED"
  }
}

resource "aws_efs_access_point" "_" {
  file_system_id = aws_efs_file_system._.id

  dynamic "posix_user" {
    for_each = local.pin_posix_user ? [1] : []

    content {
      uid = local.access_point_uid
      gid = local.access_point_gid
    }
  }

  root_directory {
    path = local.access_point_path

    creation_info {
      owner_uid   = local.owner_uid
      owner_gid   = local.owner_gid
      permissions = local.defaults.permissions
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${var.purpose}"
  })
}

# --- Network access ---------------------------------------------------------

resource "aws_security_group" "_" {
  name_prefix = "${var.name}-${var.purpose}-efs-"
  description = "Controls NFS access to the ${var.name} ${var.purpose} filesystem"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-${var.purpose}-efs"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Keyed by position rather than by the security group id, which is unknown at
# plan time when the referenced group is created in the same apply.
resource "aws_vpc_security_group_ingress_rule" "nfs_sg" {
  count = length(var.allow_from_security_group_ids)

  security_group_id            = aws_security_group._.id
  description                  = "NFS"
  referenced_security_group_id = var.allow_from_security_group_ids[count.index]
  from_port                    = 2049
  to_port                      = 2049
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "nfs_cidr" {
  for_each = toset(var.allow_from_cidr_blocks)

  security_group_id = aws_security_group._.id
  description       = "NFS"
  cidr_ipv4         = each.value
  from_port         = 2049
  to_port           = 2049
  ip_protocol       = "tcp"
}

resource "aws_efs_mount_target" "_" {
  count = length(var.subnet_ids)

  file_system_id  = aws_efs_file_system._.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = [aws_security_group._.id]
}

# --- Filesystem policy ------------------------------------------------------

data "aws_iam_policy_document" "filesystem" {
  count = local.restrict_mount ? 1 : 0

  statement {
    sid    = "AllowMountFromNamedRoles"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.restrict_mount_to_role_arns
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
    ]

    resources = [aws_efs_file_system._.arn]
  }

  statement {
    sid    = "DenyMountFromOtherPrincipals"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:ClientRootAccess",
    ]

    resources = [aws_efs_file_system._.arn]

    condition {
      test     = "ArnNotLike"
      variable = "aws:PrincipalArn"
      values   = local.mount_principal_arn_patterns
    }
  }

  dynamic "statement" {
    for_each = var.enforce_in_transit_encryption ? [1] : []

    content {
      sid    = "DenyUnencryptedTransport"
      effect = "Deny"

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      actions   = ["elasticfilesystem:*"]
      resources = [aws_efs_file_system._.arn]

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
    }
  }
}

resource "aws_efs_file_system_policy" "_" {
  count = local.restrict_mount ? 1 : 0

  file_system_id = aws_efs_file_system._.id
  policy         = data.aws_iam_policy_document.filesystem[0].json
}

# --- Alarms -----------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "storage" {
  count = length(var.alarm_sns_topic_arns) > 0 ? 1 : 0

  alarm_name          = "${var.name}-${var.purpose}-EFS-High-Storage-Usage"
  alarm_description   = "Stored bytes on the ${var.name} ${var.purpose} filesystem exceed ${var.alarm_storage_threshold_bytes}"
  namespace           = "AWS/EFS"
  metric_name         = "StorageBytes"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.alarm_storage_threshold_bytes
  period              = 300
  evaluation_periods  = 5
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns

  dimensions = {
    FileSystemId = aws_efs_file_system._.id
  }

  tags = var.tags
}
