data "aws_caller_identity" "current" {}
# .name rather than .region: .region only exists in aws provider v6, and
# this module supports >= 5.0.0. .name works in both, deprecated in v6.
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_eks_cluster" "_" {
  count = var.lookup_cluster ? 1 : 0
  name  = var.cluster_name
}

locals {
  # Looking the cluster up only works when it already exists. When it is created
  # in the same apply, the caller passes oidc_provider through instead.
  oidc_provider     = var.lookup_cluster ? replace(data.aws_eks_cluster._[0].identity[0].oidc[0].issuer, "https://", "") : var.oidc_provider
  oidc_provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"

  # The service-account role runs the platform pods; they assume the jobs and
  # datasets roles for per-job and per-dataset credentials.
  trusted_role_arns = concat([aws_iam_role.service_account.arn], var.additional_trusted_role_arns)

  audit_log_group_arn = local.create_logging ? aws_cloudwatch_log_group.audit[0].arn : null
  job_log_group_arn   = local.create_logging ? aws_cloudwatch_log_group.jobs[0].arn : null

  log_group_resources = local.create_logging ? [
    local.audit_log_group_arn,
    local.job_log_group_arn,
    "${local.audit_log_group_arn}:*",
    "${local.job_log_group_arn}:*",
  ] : []

  log_archive_resources = flatten([
    for key, _ in local.log_archive_buckets : [
      aws_s3_bucket.log_archive[key].arn,
      "${aws_s3_bucket.log_archive[key].arn}/*",
    ]
  ])
}

# --- Service account (IRSA) role --------------------------------------------

data "aws_iam_policy_document" "service_account_trust" {
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
      values   = [for sa in var.service_account_names : "system:serviceaccount:${var.service_account_namespace}:${sa}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service_account" {
  name               = "juliahub-compute.${var.name}"
  assume_role_policy = data.aws_iam_policy_document.service_account_trust.json

  tags = var.tags
}

# --- Trust policy shared by the assumable roles -----------------------------

data "aws_iam_policy_document" "assumable_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.trusted_role_arns
    }
  }
}

resource "aws_iam_role" "jobs" {
  name                 = "jobs.${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.assumable_role_trust.json
  max_session_duration = var.jobs_role_max_session_duration

  tags = var.tags
}

resource "aws_iam_role" "datasets" {
  name                 = "datasets.${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.assumable_role_trust.json
  max_session_duration = var.datasets_role_max_session_duration

  tags = var.tags
}

resource "aws_iam_role" "job_outputs" {
  name                 = "job-outputs.${var.name}"
  assume_role_policy   = data.aws_iam_policy_document.assumable_role_trust.json
  max_session_duration = var.job_outputs_role_max_session_duration

  tags = var.tags
}

# --- Datasets policy --------------------------------------------------------

data "aws_iam_policy_document" "datasets" {
  statement {
    sid       = "ListBucketScopedToPlatformPrefixes"
    actions   = ["s3:ListBucket"]
    resources = [local.datasets_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = local.datasets_list_prefixes
    }
  }

  statement {
    sid = "ObjectAccessWithinPlatformPrefixes"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObject",
      "s3:GetObjectAttributes",
      "s3:GetObjectTagging",
      "s3:PutObjectTagging",
    ]
    resources = local.datasets_object_arns
  }
}

resource "aws_iam_policy" "datasets" {
  name        = "datasets.${var.name}"
  description = "Access to the platform prefixes of the ${local.datasets_bucket_name} bucket"
  policy      = data.aws_iam_policy_document.datasets.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "datasets_role" {
  role       = aws_iam_role.datasets.name
  policy_arn = aws_iam_policy.datasets.arn
}

# The platform pods perform server-side S3 operations under their own identity
# rather than assuming the datasets role, so they get the same policy.
resource "aws_iam_role_policy_attachment" "service_account_datasets" {
  role       = aws_iam_role.service_account.name
  policy_arn = aws_iam_policy.datasets.arn
}

# --- Job outputs policy -----------------------------------------------------

# The job runner assumes this role to mint short-lived credentials for job
# sidecars uploading result files. A session policy narrows it further to a
# single job's prefix at AssumeRole time.
data "aws_iam_policy_document" "job_outputs" {
  statement {
    sid       = "ListBucketScopedToResultsPrefix"
    actions   = ["s3:ListBucket"]
    resources = [local.datasets_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${var.results_s3_prefix}/*"]
    }
  }

  statement {
    sid       = "ListMultipartUploads"
    actions   = ["s3:ListBucketMultipartUploads"]
    resources = [local.datasets_bucket_arn]
  }

  statement {
    sid = "ObjectMultipartOps"
    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts",
    ]
    resources = [local.results_object_arn_glob]
  }
}

resource "aws_iam_policy" "job_outputs" {
  name        = "job-outputs.${var.name}"
  description = "Multipart upload access to the results prefix of the ${local.datasets_bucket_name} bucket"
  policy      = data.aws_iam_policy_document.job_outputs.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "job_outputs" {
  role       = aws_iam_role.job_outputs.name
  policy_arn = aws_iam_policy.job_outputs.arn
}

# --- Jobs policy ------------------------------------------------------------

data "aws_iam_policy_document" "jobs" {
  statement {
    sid = "JobLogStreams"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:PutLogEvents",
    ]
    resources = length(local.log_group_resources) > 0 ? local.log_group_resources : ["*"]
  }

  statement {
    sid = "JobSecrets"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UpdateSecret",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:*"]
  }

  statement {
    sid       = "ListSecrets"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "jobs" {
  name        = "jobs.${var.name}"
  description = "Log and secret access for jobs running under ${var.name}"
  policy      = data.aws_iam_policy_document.jobs.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "jobs" {
  role       = aws_iam_role.jobs.name
  policy_arn = aws_iam_policy.jobs.arn
}

# --- Platform policy --------------------------------------------------------

data "aws_iam_policy_document" "platform" {
  statement {
    sid       = "AssumeComputeRoles"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.jobs.arn, aws_iam_role.datasets.arn, aws_iam_role.job_outputs.arn]
  }

  # The platform resolves image digests and lists repositories under its own
  # identity, and nodes pull images through these actions.
  statement {
    sid = "ImageRegistryRead"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:ListImages",
    ]
    resources = ["*"]
  }

  statement {
    sid = "LogGroupManagement"
    actions = [
      "logs:CreateExportTask",
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:DescribeExportTasks",
    ]
    resources = ["*"]
  }

  # EFS backs the platform config and per-user data directories.
  statement {
    sid = "ElasticFileSystem"
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientRootAccess",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:CreateAccessPoint",
      "elasticfilesystem:DescribeAccessPoints",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "elasticfilesystem:DescribeTags",
      "elasticfilesystem:TagResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "platform" {
  name        = "juliahub-compute.${var.name}"
  description = "Platform-side access to compute roles, image registry, logs, and EFS for ${var.name}"
  policy      = data.aws_iam_policy_document.platform.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "service_account_platform" {
  role       = aws_iam_role.service_account.name
  policy_arn = aws_iam_policy.platform.arn
}

# --- Logging policy ---------------------------------------------------------

data "aws_iam_policy_document" "logging" {
  count = local.create_logging ? 1 : 0

  statement {
    sid = "WriteLogStreams"
    actions = [
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = local.log_group_resources
  }

  statement {
    sid = "ReadLogArchives"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]
    resources = local.log_archive_resources
  }
}

resource "aws_iam_policy" "logging" {
  count = local.create_logging ? 1 : 0

  name        = "logging.${var.name}"
  description = "Log group write and archive read access for ${var.name}"
  policy      = data.aws_iam_policy_document.logging[0].json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "service_account_logging" {
  count = local.create_logging ? 1 : 0

  role       = aws_iam_role.service_account.name
  policy_arn = aws_iam_policy.logging[0].arn
}
