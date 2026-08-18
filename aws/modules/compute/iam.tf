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
  name               = "juliahub-compute.${local.name_slug}"
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
  name                 = "jobs.${local.name_slug}"
  assume_role_policy   = data.aws_iam_policy_document.assumable_role_trust.json
  max_session_duration = var.jobs_role_max_session_duration

  tags = var.tags
}

resource "aws_iam_role" "datasets" {
  name                 = "datasets.${local.name_slug}"
  assume_role_policy   = data.aws_iam_policy_document.assumable_role_trust.json
  max_session_duration = var.datasets_role_max_session_duration

  tags = var.tags
}

resource "aws_iam_role" "job_outputs" {
  name                 = "job-outputs.${local.name_slug}"
  assume_role_policy   = data.aws_iam_policy_document.assumable_role_trust.json
  max_session_duration = var.job_outputs_role_max_session_duration

  tags = var.tags
}

# --- Datasets policy --------------------------------------------------------

resource "aws_iam_policy" "datasets" {
  name        = "datasets.${local.name_slug}"
  description = "Access to the platform prefixes of the ${local.datasets_bucket_name} bucket"
  policy = templatefile("${path.module}/policies/datasets.json.tftpl", {
    datasets_bucket_arn    = local.datasets_bucket_arn
    datasets_list_prefixes = local.datasets_list_prefixes
    datasets_object_arns   = local.datasets_object_arns
  })

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
resource "aws_iam_policy" "job_outputs" {
  name        = "job-outputs.${local.name_slug}"
  description = "Multipart upload access to the results prefix of the ${local.datasets_bucket_name} bucket"
  policy = templatefile("${path.module}/policies/job-outputs.json.tftpl", {
    datasets_bucket_arn     = local.datasets_bucket_arn
    results_s3_prefix       = var.results_s3_prefix
    results_object_arn_glob = local.results_object_arn_glob
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "job_outputs" {
  role       = aws_iam_role.job_outputs.name
  policy_arn = aws_iam_policy.job_outputs.arn
}

# --- Jobs policy ------------------------------------------------------------

resource "aws_iam_policy" "jobs" {
  name        = "jobs.${local.name_slug}"
  description = "Log and secret access for jobs running under ${local.name_slug}"
  policy = templatefile("${path.module}/policies/jobs.json.tftpl", {
    log_group_resources = length(local.log_group_resources) > 0 ? local.log_group_resources : ["*"]
    partition           = data.aws_partition.current.partition
    account_id          = data.aws_caller_identity.current.account_id
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "jobs" {
  role       = aws_iam_role.jobs.name
  policy_arn = aws_iam_policy.jobs.arn
}

# --- Platform policy --------------------------------------------------------

resource "aws_iam_policy" "platform" {
  name        = "juliahub-compute.${local.name_slug}"
  description = "Platform-side access to compute roles, image registry, logs, and EFS for ${local.name_slug}"
  policy = templatefile("${path.module}/policies/platform.json.tftpl", {
    compute_role_arns = [aws_iam_role.jobs.arn, aws_iam_role.datasets.arn, aws_iam_role.job_outputs.arn]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "service_account_platform" {
  role       = aws_iam_role.service_account.name
  policy_arn = aws_iam_policy.platform.arn
}

# --- Logging policy ---------------------------------------------------------

resource "aws_iam_policy" "logging" {
  count = local.create_logging ? 1 : 0

  name        = "logging.${local.name_slug}"
  description = "Log group write and archive read access for ${local.name_slug}"
  policy = templatefile("${path.module}/policies/logging.json.tftpl", {
    log_group_resources   = local.log_group_resources
    log_archive_resources = local.log_archive_resources
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "service_account_logging" {
  count = local.create_logging ? 1 : 0

  role       = aws_iam_role.service_account.name
  policy_arn = aws_iam_policy.logging[0].arn
}
