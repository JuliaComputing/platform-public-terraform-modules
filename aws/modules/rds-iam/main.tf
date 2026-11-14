# IRSA roles for RDS IAM database authentication.
#
# The platform chart (postgres.external.auth: iam) connects to the database
# under three identities, each with only what it needs:
#
#   - the platform services, on the existing platform service account role:
#     rds-db:connect as the services' database role.
#   - the bootstrap Job (juliahub-bootstrap): rds-db:connect as the admin
#     database role that owns the databases and runs the migrations.
#   - the create-database-user hook (juliahub-db-provisioner): read access to
#     the RDS-managed master user secret, which it uses to create both roles.
#     Nothing else is allowed to read that secret.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster" "_" {
  count = var.lookup_cluster ? 1 : 0
  name  = var.cluster_name
}

locals {
  oidc_provider     = var.lookup_cluster ? replace(data.aws_eks_cluster._[0].identity[0].oidc[0].issuer, "https://", "") : var.oidc_provider
  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"

  role_name_prefix = substr(var.name, 0, 48)
}

data "aws_iam_policy_document" "trust" {
  for_each = toset(concat(
    [var.bootstrap_service_account_name],
    var.manage_master_user_password ? [var.provisioner_service_account_name] : [],
  ))

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
      values   = ["system:serviceaccount:${var.namespace}:${each.value}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

# --- Bootstrap Job ------------------------------------------------------------

resource "aws_iam_role" "bootstrap" {
  name               = "${local.role_name_prefix}-db-bootstrap"
  assume_role_policy = data.aws_iam_policy_document.trust[var.bootstrap_service_account_name].json

  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "bootstrap_connect" {
  name   = "rds-iam-admin-connect"
  role   = aws_iam_role.bootstrap.id
  policy = var.iam_admin_connect_policy_json
}

# --- create-database-user hook ------------------------------------------------

resource "aws_iam_role" "provisioner" {
  count = var.manage_master_user_password ? 1 : 0

  name               = "${local.role_name_prefix}-db-provisioner"
  assume_role_policy = data.aws_iam_policy_document.trust[var.provisioner_service_account_name].json

  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

resource "aws_iam_role_policy" "provisioner_master_secret" {
  count = var.manage_master_user_password ? 1 : 0

  name   = "rds-master-user-secret-read"
  role   = aws_iam_role.provisioner[0].id
  policy = var.master_user_secret_read_policy_json

  lifecycle {
    precondition {
      condition     = var.master_user_secret_read_policy_json != null
      error_message = "manage_master_user_password requires master_user_secret_read_policy_json."
    }
  }
}

# --- Platform services ----------------------------------------------------------

resource "aws_iam_role_policy" "platform_connect" {
  count = var.attach_to_platform_role ? 1 : 0

  name   = "rds-iam-connect"
  role   = var.platform_role_name
  policy = var.iam_connect_policy_json
}

# The compute module lets the platform role read every secret in the account,
# which would include the master user secret.
data "aws_iam_policy_document" "platform_deny_master_secret" {
  count = var.attach_to_platform_role && var.manage_master_user_password ? 1 : 0

  statement {
    sid       = "DenyRdsMasterUserSecret"
    effect    = "Deny"
    actions   = ["secretsmanager:*"]
    resources = [var.master_user_secret_arn]
  }
}

resource "aws_iam_role_policy" "platform_deny_master_secret" {
  count = var.attach_to_platform_role && var.manage_master_user_password ? 1 : 0

  name   = "deny-rds-master-user-secret"
  role   = var.platform_role_name
  policy = data.aws_iam_policy_document.platform_deny_master_secret[0].json

  lifecycle {
    precondition {
      condition     = var.master_user_secret_arn != null
      error_message = "manage_master_user_password requires master_user_secret_arn."
    }
  }
}
