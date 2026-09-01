variable "cluster_name" {
  description = "Name of the EKS cluster Karpenter provisions nodes for"
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
  description = "Kubernetes namespace Karpenter is installed into"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Name of the Karpenter controller service account, used as the IRSA trust subject"
  type        = string
  default     = "karpenter"
}

variable "node_role_name" {
  description = "Name of the IAM role Karpenter-provisioned nodes assume. Leave empty to derive <cluster_name>-karpenter-node."
  type        = string
  default     = ""
}

variable "controller_role_name" {
  description = "Name of the Karpenter controller IRSA role. Leave empty to derive <cluster_name>-karpenter-controller."
  type        = string
  default     = ""
}

variable "node_additional_managed_policies" {
  description = "Additional managed policy ARNs to attach to the Karpenter node role, beyond the four required for a node to join the cluster"
  type        = list(string)
  default     = []
}

variable "create_interruption_queue" {
  description = <<-EOT
    Whether to create the SQS queue and EventBridge rules that let Karpenter
    react to instance interruption notices.

    Without this, Karpenter learns about a spot interruption or scheduled
    maintenance only when the node disappears, so pods are killed rather than
    drained. Recommended whenever spot capacity is in use.
  EOT
  type        = bool
  default     = true
}

variable "interruption_queue_name" {
  description = "Name of the interruption SQS queue. Leave empty to derive <cluster_name>-karpenter."
  type        = string
  default     = ""
}

variable "interruption_queue_message_retention_seconds" {
  description = "How long an unprocessed interruption message is retained"
  type        = number
  default     = 300
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
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
