# --- IAM database authentication ---------------------------------------------

# .name rather than .region: .region only exists in aws provider v6, and
# this module supports >= 5.0.0. .name works in both, deprecated in v6.
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  db_user_arn_prefix    = "arn:${data.aws_partition.current.partition}:rds-db:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:dbuser:${aws_db_instance._.resource_id}"
  iam_db_user_arn       = "${local.db_user_arn_prefix}/${var.iam_db_username}"
  iam_admin_db_user_arn = "${local.db_user_arn_prefix}/${var.iam_admin_db_username}"

  master_user_secret_arn = try(aws_db_instance._.master_user_secret[0].secret_arn, null)
}

data "aws_iam_policy_document" "iam_connect" {
  count = var.iam_database_authentication_enabled ? 1 : 0

  statement {
    sid       = "RdsIamConnect"
    actions   = ["rds-db:connect"]
    resources = [local.iam_db_user_arn]
  }
}

data "aws_iam_policy_document" "iam_admin_connect" {
  count = var.iam_database_authentication_enabled ? 1 : 0

  statement {
    sid       = "RdsIamAdminConnect"
    actions   = ["rds-db:connect"]
    resources = [local.iam_admin_db_user_arn]
  }
}

data "aws_iam_policy_document" "master_user_secret_read" {
  count = var.manage_master_user_password ? 1 : 0

  statement {
    sid       = "ReadRdsMasterUserSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [local.master_user_secret_arn]
  }

  dynamic "statement" {
    for_each = var.master_user_secret_kms_key_id == null ? [] : [1]

    content {
      sid       = "DecryptRdsMasterUserSecret"
      actions   = ["kms:Decrypt"]
      resources = [aws_db_instance._.master_user_secret[0].kms_key_id]
    }
  }
}
