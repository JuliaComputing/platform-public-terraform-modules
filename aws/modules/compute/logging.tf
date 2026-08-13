locals {
  create_logging = var.create_logging

  audit_log_group_name          = var.audit_log_group_name == "" ? "${var.name}-audit" : var.audit_log_group_name
  audit_log_archive_bucket_name = var.audit_log_archive_bucket_name == "" ? "${local.name_slug}-audit-archive" : var.audit_log_archive_bucket_name
  job_log_group_name            = var.job_log_group_name == "" ? "${var.name}-job-logs" : var.job_log_group_name
  job_log_archive_bucket_name   = var.job_log_archive_bucket_name == "" ? "${local.name_slug}-job-logs-archive" : var.job_log_archive_bucket_name

  log_archive_buckets = local.create_logging ? {
    audit = local.audit_log_archive_bucket_name
    jobs  = local.job_log_archive_bucket_name
  } : {}
}

resource "aws_cloudwatch_log_group" "audit" {
  count = local.create_logging ? 1 : 0

  name              = local.audit_log_group_name
  retention_in_days = var.audit_log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "jobs" {
  count = local.create_logging ? 1 : 0

  name              = local.job_log_group_name
  retention_in_days = var.job_log_retention_days

  tags = var.tags
}

resource "aws_s3_bucket" "log_archive" {
  for_each = local.log_archive_buckets

  bucket        = each.value
  force_destroy = var.force_destroy_log_buckets

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  for_each = local.log_archive_buckets

  bucket = aws_s3_bucket.log_archive[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "log_archive" {
  for_each = local.log_archive_buckets

  bucket = aws_s3_bucket.log_archive[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  for_each = local.log_archive_buckets

  bucket = aws_s3_bucket.log_archive[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# CloudWatch Logs export tasks write archived log data into these buckets.
data "aws_iam_policy_document" "log_archive" {
  for_each = local.log_archive_buckets

  statement {
    sid     = "CloudWatchLogsGetBucketAcl"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    resources = [aws_s3_bucket.log_archive[each.key].arn]
  }

  statement {
    sid     = "CloudWatchLogsPutObject"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.name}.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.log_archive[each.key].arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.log_archive[each.key].arn,
      "${aws_s3_bucket.log_archive[each.key].arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "log_archive" {
  for_each = local.log_archive_buckets

  bucket = aws_s3_bucket.log_archive[each.key].id
  policy = data.aws_iam_policy_document.log_archive[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.log_archive]
}
