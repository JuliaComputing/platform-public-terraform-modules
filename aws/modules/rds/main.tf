locals {
  parameter_group_family  = var.parameter_group_family == "" ? "postgres${var.postgresql_version}" : var.parameter_group_family
  restoring_from_snapshot = var.snapshot_identifier != ""
  create_monitoring_role  = var.monitoring_interval > 0 && var.monitoring_role_arn == ""
  monitoring_enabled      = var.monitoring_interval > 0

  monitoring_role_arn = local.monitoring_enabled ? (
    local.create_monitoring_role ? aws_iam_role.monitoring[0].arn : var.monitoring_role_arn
  ) : null
}

resource "random_password" "master" {
  count = local.restoring_from_snapshot ? 0 : 1

  length  = 32
  special = false # avoids URI-escaping problems in connection strings
}

# --- Networking -------------------------------------------------------------

resource "aws_db_subnet_group" "_" {
  count = length(var.subnet_ids) == 0 ? 0 : 1

  name       = var.identifier
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = var.identifier
  })
}

data "aws_subnet" "first" {
  count = length(var.subnet_ids) == 0 ? 0 : 1
  id    = var.subnet_ids[0]
}

data "aws_vpc" "default" {
  count   = length(var.subnet_ids) == 0 ? 1 : 0
  default = true
}

resource "aws_security_group" "_" {
  name_prefix = "${var.identifier}-rds-"
  description = "Controls access to the ${var.identifier} PostgreSQL instance"
  vpc_id      = length(var.subnet_ids) == 0 ? data.aws_vpc.default[0].id : data.aws_subnet.first[0].vpc_id

  tags = merge(var.tags, {
    Name = "${var.identifier}-rds"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_cidr" {
  for_each = toset(var.allow_from_cidr_blocks)

  security_group_id = aws_security_group._.id
  description       = "PostgreSQL"
  cidr_ipv4         = each.value
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
}

# Keyed by position rather than by the security group id, which is unknown at
# plan time when the referenced group is created in the same apply.
resource "aws_vpc_security_group_ingress_rule" "postgres_sg" {
  count = length(var.allow_from_security_group_ids)

  security_group_id            = aws_security_group._.id
  description                  = "PostgreSQL"
  referenced_security_group_id = var.allow_from_security_group_ids[count.index]
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group._.id
  description       = "Allow all outbound"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# --- Enhanced monitoring ----------------------------------------------------

data "aws_iam_policy_document" "monitoring_assume_role" {
  count = local.create_monitoring_role ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "monitoring" {
  count = local.create_monitoring_role ? 1 : 0

  name_prefix        = "${substr(var.identifier, 0, 24)}-rds-mon-"
  assume_role_policy = data.aws_iam_policy_document.monitoring_assume_role[0].json

  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "monitoring" {
  count = local.create_monitoring_role ? 1 : 0

  role       = aws_iam_role.monitoring[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_partition" "current" {}

# --- Parameter group --------------------------------------------------------

resource "aws_db_parameter_group" "_" {
  name_prefix = "${var.identifier}-"
  family      = local.parameter_group_family
  description = "Parameter group for ${var.identifier}"

  parameter {
    name         = "rds.force_ssl"
    value        = var.force_ssl ? "1" : "0"
    apply_method = "pending-reboot"
  }

  dynamic "parameter" {
    for_each = var.additional_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# --- Instance ---------------------------------------------------------------

resource "aws_db_instance" "_" {
  identifier = var.identifier

  snapshot_identifier = local.restoring_from_snapshot ? var.snapshot_identifier : null

  # These are set by the snapshot when restoring, and must be null in that case.
  engine            = local.restoring_from_snapshot ? null : "postgres"
  engine_version    = local.restoring_from_snapshot ? null : var.postgresql_version
  allocated_storage = local.restoring_from_snapshot ? null : var.allocated_storage
  username          = local.restoring_from_snapshot ? null : var.username
  password          = local.restoring_from_snapshot ? null : random_password.master[0].result
  db_name           = local.restoring_from_snapshot || var.database_name == "" ? null : var.database_name

  instance_class        = var.instance_class
  max_allocated_storage = var.max_allocated_storage
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = var.kms_key_id == "" ? null : var.kms_key_id
  multi_az              = var.multi_az

  parameter_group_name   = aws_db_parameter_group._.name
  db_subnet_group_name   = length(var.subnet_ids) == 0 ? null : aws_db_subnet_group._[0].name
  vpc_security_group_ids = [aws_security_group._.id]
  publicly_accessible    = var.publicly_accessible
  ca_cert_identifier     = var.ca_cert_identifier

  maintenance_window          = var.maintenance_window
  apply_immediately           = var.apply_immediately
  allow_major_version_upgrade = var.allow_major_version_upgrade
  auto_minor_version_upgrade  = var.auto_minor_version_upgrade

  backup_window           = var.backup_window
  backup_retention_period = var.backup_retention_period
  copy_tags_to_snapshot   = true

  performance_insights_enabled          = local.monitoring_enabled
  performance_insights_retention_period = local.monitoring_enabled ? var.performance_insights_retention_period : null
  monitoring_interval                   = var.monitoring_interval
  monitoring_role_arn                   = local.monitoring_role_arn

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.identifier}-final"

  tags = var.tags
}
