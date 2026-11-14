variable "name" {
  description = "Prefix for the IAM role names, typically the RDS instance identifier. Truncated to 48 characters."
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster the platform runs in. Used to discover the cluster OIDC provider for the IRSA trust policies."
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

variable "namespace" {
  description = "Kubernetes namespace the platform is deployed into. Used as the IRSA trust subject."
  type        = string
  default     = "juliahub"
}

variable "bootstrap_service_account_name" {
  description = "Service account the platform chart's bootstrap Job runs as"
  type        = string
  default     = "juliahub-bootstrap"
}

variable "provisioner_service_account_name" {
  description = "Service account the platform chart's create-database-user hook runs as"
  type        = string
  default     = "juliahub-db-provisioner"
}

variable "iam_connect_policy_json" {
  description = "The rds module's iam_connect_policy_json output: rds-db:connect as the platform services' database role"
  type        = string
}

variable "iam_admin_connect_policy_json" {
  description = "The rds module's iam_admin_connect_policy_json output: rds-db:connect as the bootstrap Job's database role"
  type        = string
}

variable "platform_role_name" {
  description = "Name of the platform service account's IAM role, the compute module's service_account_role_name output. Gets rds-db:connect as the services' database role, and is denied the master user secret. Requires attach_to_platform_role."
  type        = string
  default     = null
}

variable "attach_to_platform_role" {
  description = "Whether to attach the policies to platform_role_name. A separate flag because the count it drives must be known at plan time, which a role name from another module may not be."
  type        = bool
  default     = false
}

variable "manage_master_user_password" {
  description = "Whether the instance has an RDS-managed master password (the rds module's manage_master_user_password). Creates the create-database-user hook's role, and denies the secret to the platform role."
  type        = bool
  default     = false
}

variable "master_user_secret_arn" {
  description = "The rds module's master_user_secret_arn output. Required with manage_master_user_password."
  type        = string
  default     = null
}

variable "master_user_secret_read_policy_json" {
  description = "The rds module's master_user_secret_read_policy_json output. Required with manage_master_user_password."
  type        = string
  default     = null
}

variable "permissions_boundary_arn" {
  description = <<-EOT
    ARN of an IAM permissions boundary to attach to every IAM role this module
    creates. Leave null to create roles without a boundary.

    Set this in accounts where iam:CreateRole is only permitted when the new
    role carries an approved boundary, which is a common guardrail in
    centrally governed AWS organizations. Without it the apply fails on the
    first role with AccessDenied even though the caller holds iam:CreateRole.
  EOT
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to the IAM roles"
  type        = map(string)
  default     = {}
}
