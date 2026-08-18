locals {
  # S3 bucket names cannot contain dots when accessed over TLS with virtual-host
  # addressing, so a domain-style hostname is flattened to hyphens.
  name_slug = var.resource_name_prefix != "" ? var.resource_name_prefix : replace(var.platform_hostname, ".", "-")

  datasets_bucket_name = var.datasets_bucket_name == "" ? "${local.name_slug}-datasets" : var.datasets_bucket_name

  # Deliberately the hostname, not the slug: this is a CORS origin, and a
  # browser upload from anything else is refused.
  allowed_origins = length(var.allowed_origins) == 0 ? [var.platform_hostname] : var.allowed_origins

  s3_prefixes = [
    var.datasets_s3_prefix,
    var.results_s3_prefix,
    var.applications_s3_prefix,
    var.inputs_s3_prefix,
    var.lfs_s3_prefix,
  ]

  datasets_bucket_arn = var.create_datasets_bucket ? aws_s3_bucket.datasets[0].arn : "arn:${data.aws_partition.current.partition}:s3:::${local.datasets_bucket_name}"

  datasets_list_prefixes  = [for p in local.s3_prefixes : "${p}/*"]
  datasets_object_arns    = [for p in local.s3_prefixes : "${local.datasets_bucket_arn}/${p}/*"]
  results_object_arn_glob = "${local.datasets_bucket_arn}/${var.results_s3_prefix}/*"
}

resource "aws_s3_bucket" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket        = local.datasets_bucket_name
  force_destroy = var.force_destroy_datasets_bucket

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  block_public_acls       = true
  block_public_policy     = false # the bucket policy below is not public, but does name external principals
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.datasets_noncurrent_version_expiration_days
    }
  }

  rule {
    id     = "cleanup-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.datasets]
}

# The platform UI uploads datasets directly to S3 from the browser, so the
# bucket must allow cross-origin PUT from the platform hostname.
resource "aws_s3_bucket_cors_configuration" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = [for o in local.allowed_origins : "https://${o}"]
    expose_headers  = []
  }
}

resource "aws_s3_bucket_notification" "datasets" {
  count = var.create_datasets_bucket && length(var.datasets_bucket_notifications) > 0 ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id

  dynamic "queue" {
    for_each = var.datasets_bucket_notifications

    content {
      id            = queue.key
      queue_arn     = queue.value.queue_arn
      events        = queue.value.events
      filter_prefix = queue.value.filter_prefix
    }
  }
}

data "aws_iam_policy_document" "datasets_bucket" {
  count = var.create_datasets_bucket ? 1 : 0

  source_policy_documents = var.additional_datasets_bucket_policy_statements

  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.datasets[0].arn,
      "${aws_s3_bucket.datasets[0].arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "datasets" {
  count = var.create_datasets_bucket ? 1 : 0

  bucket = aws_s3_bucket.datasets[0].id
  policy = data.aws_iam_policy_document.datasets_bucket[0].json

  depends_on = [aws_s3_bucket_public_access_block.datasets]
}
