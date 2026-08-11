variable "identifier" {
  description = "Identifier for the RDS instance. Also used to name the subnet group, parameter group, and security group."
  type        = string
}

variable "postgresql_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.m7g.large"
}

variable "allocated_storage" {
  description = "Initial storage in GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Upper bound in GB for storage autoscaling. Set equal to allocated_storage to disable autoscaling."
  type        = number
  default     = 1000
}

variable "username" {
  description = "Master username for the database"
  type        = string
  default     = "postgres"
}

variable "database_name" {
  description = "Name of a database to create on the instance. Leave empty to create none, in which case the platform expects the default postgres database."
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Subnet IDs for the DB subnet group. Use private subnets. Leaving this empty places the instance in the account's default VPC, which is not recommended."
  type        = list(string)
  default     = []
}

variable "allow_from_cidr_blocks" {
  description = "CIDR blocks permitted to reach the database on port 5432. Defaults to empty, so no ingress is allowed until you set either this or allow_from_security_group_ids."
  type        = list(string)
  default     = []
}

variable "allow_from_security_group_ids" {
  description = "Security group IDs permitted to reach the database on port 5432. Prefer this over CIDR blocks; pass the EKS cluster security group so only cluster workloads can connect."
  type        = list(string)
  default     = []
}

variable "publicly_accessible" {
  description = "Whether the instance gets a public IP address"
  type        = bool
  default     = false
}

variable "force_ssl" {
  description = "Whether to require SSL connections via the rds.force_ssl parameter. The platform connects with requiresSSL enabled."
  type        = bool
  default     = true
}

variable "ca_cert_identifier" {
  description = "RDS CA certificate identifier. See https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/UsingWithRDS.SSL.html"
  type        = string
  default     = "rds-ca-rsa2048-g1"
}

variable "parameter_group_family" {
  description = "Parameter group family. Leave empty to derive postgres<postgresql_version>."
  type        = string
  default     = ""
}

variable "additional_parameters" {
  description = <<-EOT
    Additional DB parameter group parameters.

    additional_parameters = [
      {
        name         = "log_min_duration_statement"
        value        = "1000"
        apply_method = "immediate"
      },
    ]
  EOT
  type = list(object({
    name         = string
    value        = string
    apply_method = optional(string, "immediate")
  }))
  default = []
}

variable "backup_retention_period" {
  description = "Days to retain automated backups"
  type        = number
  default     = 30
}

variable "backup_window" {
  description = "Daily backup window in UTC, as hh24:mi-hh24:mi"
  type        = string
  default     = "07:26-07:56"
}

variable "maintenance_window" {
  description = "Weekly maintenance window, as ddd:hh24:mi-ddd:hh24:mi"
  type        = string
  default     = "Wed:03:00-Wed:06:00"
}

variable "apply_immediately" {
  description = "Whether modifications are applied immediately rather than in the next maintenance window. Applying immediately can cause a brief outage."
  type        = bool
  default     = false
}

variable "allow_major_version_upgrade" {
  description = "Whether major version upgrades are permitted"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Whether minor version upgrades are applied automatically during the maintenance window"
  type        = bool
  default     = true
}

variable "storage_encrypted" {
  description = "Whether storage is encrypted at rest"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "ARN of a KMS key for storage encryption. Leave empty to use the default RDS key."
  type        = string
  default     = ""
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled. Disable this before destroying the instance."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on destroy. Leaving this false means a snapshot named <identifier>-final is taken."
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "Snapshot identifier to restore from. Leave empty to create a fresh instance."
  type        = string
  default     = ""
}

variable "multi_az" {
  description = "Whether to deploy a standby in a second availability zone for failover"
  type        = bool
  default     = false
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval in seconds. Set to 0 to disable enhanced monitoring and Performance Insights."
  type        = number
  default     = 60
}

variable "monitoring_role_arn" {
  description = "ARN of an existing IAM role for enhanced monitoring. Leave empty to have the module create one when monitoring_interval is greater than zero."
  type        = string
  default     = ""
}

variable "performance_insights_retention_period" {
  description = "Days to retain Performance Insights data. Valid values are 7, 731, or a multiple of 31."
  type        = number
  default     = 7
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs notified by the CloudWatch alarms. Leaving this empty creates no alarms."
  type        = list(string)
  default     = []
}

variable "alarm_high_cpu_threshold" {
  description = "CPU utilization percentage above which the high-CPU alarm fires"
  type        = number
  default     = 70
}

variable "alarm_low_memory_threshold_bytes" {
  description = "Freeable memory in bytes below which the low-memory alarm fires"
  type        = number
  default     = 1e9
}

variable "alarm_low_storage_threshold_bytes" {
  description = "Free storage in bytes below which the low-storage alarm fires"
  type        = number
  default     = 5e8
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
