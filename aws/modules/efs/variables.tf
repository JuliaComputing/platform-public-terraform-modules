variable "name" {
  description = "Name used to label the filesystem and its security group"
  type        = string
}

variable "purpose" {
  description = <<-EOT
    Which platform directory this filesystem backs, which selects the access point defaults.

    - config: the shared configuration directory, mounted read-write by every
      platform component. Roots at /config with an unrestricted POSIX owner, so
      each component writes as its own user.
    - userdata: per-user job storage. Roots at /data and pins the POSIX user to
      the job runtime uid/gid, so job containers get a consistent identity.
  EOT
  type        = string

  validation {
    condition     = contains(["config", "userdata"], var.purpose)
    error_message = "purpose must be one of: config, userdata."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the mount targets live in"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs to create mount targets in. Pass at most one subnet per availability zone: EFS rejects a second mount target in the same zone, and the zone of a subnet is not known until apply so the module cannot deduplicate for you. Use the private subnets."
  type        = list(string)
}

variable "allow_from_security_group_ids" {
  description = "Security group IDs permitted to reach the filesystem on the NFS port. Pass the EKS cluster security group so cluster workloads can mount it."
  type        = list(string)
  default     = []
}

variable "allow_from_cidr_blocks" {
  description = "CIDR blocks permitted to reach the filesystem on the NFS port. Prefer allow_from_security_group_ids. Setting neither leaves the filesystem unreachable."
  type        = list(string)
  default     = []
}

variable "encrypted" {
  description = "Whether the filesystem is encrypted at rest"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "ARN of a KMS key for encryption at rest. Leave empty to use the default EFS key."
  type        = string
  default     = ""
}

variable "throughput_mode" {
  description = "Throughput mode: elastic, bursting, or provisioned"
  type        = string
  default     = "elastic"

  validation {
    condition     = contains(["elastic", "bursting", "provisioned"], var.throughput_mode)
    error_message = "throughput_mode must be one of: elastic, bursting, provisioned."
  }
}

variable "provisioned_throughput_in_mibps" {
  description = "Throughput in MiB/s when throughput_mode is provisioned"
  type        = number
  default     = null
}

variable "performance_mode" {
  description = "Performance mode: generalPurpose or maxIO. generalPurpose has lower latency and suits both platform directories."
  type        = string
  default     = "generalPurpose"
}

variable "transition_to_ia" {
  description = <<-EOT
    When files move to Infrequent Access storage, for example AFTER_14_DAYS.

    Set to "none" to keep everything in Standard. The config directory serves
    package tarballs on demand, so its whole contents are read continually and
    IA tiering adds per-access charges without a storage saving. Userdata has a
    colder access pattern and does benefit from tiering.
  EOT
  type        = string
  default     = "none"
}

variable "transition_to_primary_storage_class" {
  description = "When IA-resident files move back to Standard on access. Ignored when transition_to_ia is \"none\"."
  type        = string
  default     = "AFTER_1_ACCESS"
}

variable "enable_backup_policy" {
  description = "Whether to enable AWS Backup for the filesystem. Recommended for the config directory, which holds platform state."
  type        = bool
  default     = false
}

variable "access_point_path" {
  description = "Root directory the access point exposes. Leave empty to use /config or /data according to purpose."
  type        = string
  default     = ""
}

variable "access_point_uid" {
  description = "POSIX uid the access point enforces. Leave null to use the default for the purpose: unset for config, 8000 for userdata."
  type        = number
  default     = null
}

variable "access_point_gid" {
  description = "POSIX gid the access point enforces. Leave null to use the default for the purpose."
  type        = number
  default     = null
}

variable "restrict_mount_to_role_arns" {
  description = <<-EOT
    IAM role ARNs permitted to mount the filesystem.

    When set, a filesystem policy is attached allowing these principals to
    mount through a mount target; anything else is refused by IAM's implicit
    deny. Pass the EKS node role, since the EFS CSI node daemonset mounts
    under the node identity rather than the pod's.

    Mounts must then authenticate, so every EFS PersistentVolume needs the
    `iam` mount option. Leaving this empty attaches no policy, and access is
    controlled by the mount target security groups alone.
  EOT
  type        = list(string)
  default     = []
}

variable "enforce_in_transit_encryption" {
  description = "Whether the filesystem policy denies mounts that do not use TLS. Only applies when restrict_mount_to_role_arns is set."
  type        = bool
  default     = true
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs notified when stored bytes exceed the threshold. Leaving this empty creates no alarm."
  type        = list(string)
  default     = []
}

variable "alarm_storage_threshold_bytes" {
  description = "Stored bytes above which the storage alarm fires"
  type        = number
  default     = 1e11
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
