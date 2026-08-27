variable "platform_hostname" {
  description = <<-EOT
    Hostname users load the platform from, e.g. juliahub.example.com.

    This is the default CORS origin for direct dataset uploads, so it has to be
    the real hostname — a browser upload from a different origin is refused.
    It also seeds the default IAM, bucket and log group names, with dots
    flattened to hyphens where S3 requires it; set `resource_name_prefix` if
    those need to be shorter than the hostname allows.
  EOT
  type        = string
}

variable "resource_name_prefix" {
  description = <<-EOT
    Prefix for generated IAM role, bucket and log group names. Defaults to
    `platform_hostname` with dots replaced by hyphens.

    Set this when the hostname is too long for what it feeds: S3 bucket names
    are capped at 63 characters and IAM role names at 64, and the derived
    suffixes push a long hostname over, failing the apply partway through. It
    does not affect the CORS origin.
  EOT
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "Name of the EKS cluster the platform runs in. Used to discover the cluster OIDC provider for the IRSA trust policy."
  type        = string
}

variable "lookup_cluster" {
  description = "Whether to look the cluster up by name to derive its OIDC issuer. Set false and supply oidc_provider when the cluster is created in the same apply, since the count on the lookup must be known at plan time."
  type        = bool
  default     = true
}

variable "oidc_provider" {
  description = <<-EOT
    OIDC issuer host and path for the cluster, without the https:// scheme, as
    the eks module's oidc_provider output gives it.

    Leave empty to look the cluster up by name. Supply it when the cluster is
    created in the same apply as this module, since the lookup then fails at
    plan time with "couldn't find resource".
  EOT
  type        = string
  default     = ""
}

variable "service_account_namespace" {
  description = "Kubernetes namespace the platform is deployed into. Used as the IRSA trust subject."
  type        = string
  default     = "juliahub"
}

variable "service_account_names" {
  description = "Service accounts in the platform namespace permitted to assume the compute IRSA role. The platform, job-runner and Fluent Bit service accounts all carry the role annotation, so all three are trusted by default."
  type        = list(string)
  default     = ["juliahub-platform", "juliarun", "fluent-bit"]
}

# --- Datasets bucket --------------------------------------------------------

variable "datasets_bucket_name" {
  description = "Name of the S3 bucket holding datasets, job results, and application data. Leave empty to derive <name>-datasets with dots replaced by hyphens."
  type        = string
  default     = ""
}

variable "create_datasets_bucket" {
  description = "Whether to create the datasets bucket. Set false to use an existing bucket, in which case datasets_bucket_name is required."
  type        = bool
  default     = true
}

variable "datasets_noncurrent_version_expiration_days" {
  description = "Days after which noncurrent object versions in the datasets bucket are expired"
  type        = number
  default     = 30
}

variable "force_destroy_datasets_bucket" {
  description = "Whether terraform destroy may delete the datasets bucket while it still holds objects. This destroys customer data; leave false outside of test environments."
  type        = bool
  default     = false
}

variable "allowed_origins" {
  description = "Origins permitted to PUT directly to the datasets bucket via CORS, without the scheme. The platform UI uploads datasets straight to S3, so this must include the platform hostname. Defaults to [name]."
  type        = list(string)
  default     = []
}

variable "datasets_s3_prefix" {
  description = "Key prefix for datasets"
  type        = string
  default     = "datasets"
}

variable "results_s3_prefix" {
  description = "Key prefix for job results"
  type        = string
  default     = "results"
}

variable "applications_s3_prefix" {
  description = "Key prefix for application data"
  type        = string
  default     = "applications"
}

variable "inputs_s3_prefix" {
  description = "Key prefix for job inputs"
  type        = string
  default     = "inputs"
}

variable "lfs_s3_prefix" {
  description = "Key prefix for Git LFS objects"
  type        = string
  default     = "lfs"
}

variable "datasets_bucket_notifications" {
  description = <<-EOT
    SQS queues notified when objects are created in the datasets bucket, keyed by a short name.

    Use this to hook up object scanning or other post-upload processing. The
    queue's own access policy must allow s3.amazonaws.com to send messages.

    datasets_bucket_notifications = {
      "scanner" = {
        queue_arn = "arn:aws:sqs:us-east-1:111122223333:object-scan"
      }
    }
  EOT
  type = map(object({
    queue_arn     = string
    events        = optional(list(string), ["s3:ObjectCreated:*"])
    filter_prefix = optional(string, null)
  }))
  default = {}
}

variable "additional_datasets_bucket_policy_statements" {
  description = "Additional IAM policy statements merged into the datasets bucket policy, as JSON-encoded strings. Use this to grant an external scanning service read and tag access to the bucket."
  type        = list(string)
  default     = []
}

# --- Logging ----------------------------------------------------------------

variable "create_logging" {
  description = "Whether to create the audit and job CloudWatch log groups and their S3 archive buckets"
  type        = bool
  default     = true
}

variable "audit_log_group_name" {
  description = "Name of the audit log group. Leave empty to derive <name>-audit."
  type        = string
  default     = ""
}

variable "audit_log_archive_bucket_name" {
  description = "Name of the audit log archive bucket. Leave empty to derive <name>-audit-archive with dots replaced by hyphens."
  type        = string
  default     = ""
}

variable "audit_log_retention_days" {
  description = "Retention in days for the audit log group"
  type        = number
  default     = 30
}

variable "job_log_group_name" {
  description = "Name of the job log group. Leave empty to derive <name>-job-logs."
  type        = string
  default     = ""
}

variable "job_log_archive_bucket_name" {
  description = "Name of the job log archive bucket. Leave empty to derive <name>-job-logs-archive with dots replaced by hyphens."
  type        = string
  default     = ""
}

variable "job_log_retention_days" {
  description = "Retention in days for the job log group"
  type        = number
  default     = 7
}

variable "force_destroy_log_buckets" {
  description = "Whether terraform destroy may delete the log archive buckets while they still hold objects"
  type        = bool
  default     = false
}

# --- IAM --------------------------------------------------------------------

variable "jobs_role_max_session_duration" {
  description = "Maximum STS session duration in seconds for the jobs role"
  type        = number
  default     = 18000
}

variable "datasets_role_max_session_duration" {
  description = "Maximum STS session duration in seconds for the datasets role"
  type        = number
  default     = 43200
}

variable "job_outputs_role_max_session_duration" {
  description = "Maximum STS session duration in seconds for the job-outputs role. Must be at least the session duration the job runner requests when issuing scoped credentials, currently 3600."
  type        = number
  default     = 3600
}

variable "additional_trusted_role_arns" {
  description = "Additional IAM role ARNs permitted to assume the jobs and datasets roles. Use this for EC2 instance profiles or other principals outside the cluster."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
