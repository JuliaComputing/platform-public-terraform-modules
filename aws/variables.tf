variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used to name the VPC and its subnets."
  type        = string
  default     = "juliahub"
}

variable "tags" {
  description = "Tags to apply to all resources. Use this for your own cost allocation and ownership tags."
  type        = map(string)
  default     = {}
}

# --- Networking -------------------------------------------------------------

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "additional_vpc_cidrs" {
  description = "Additional CIDR blocks to associate with the VPC"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default = [
    "192.168.0.0/18",
    "192.168.64.0/18",
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets, where EKS nodes run"
  type        = list(string)
  default = [
    "192.168.128.0/18",
    "192.168.192.0/18",
  ]
}

variable "availability_zones" {
  description = "Availability zones to distribute subnets across. EKS requires at least two."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1c"]
}

variable "nat_gateway_ids" {
  description = "IDs of existing NAT gateways to use. Leave empty to create one per public subnet."
  type        = list(string)
  default     = []
}

variable "map_public_ip_on_launch" {
  description = "Whether instances in the public subnets receive a public IP"
  type        = bool
  default     = true
}

variable "enable_ecr_vpc_endpoint" {
  description = "Whether to create interface VPC endpoints for ECR"
  type        = bool
  default     = true
}

variable "enable_s3_vpc_endpoint" {
  description = "Whether to create a gateway VPC endpoint for S3"
  type        = bool
  default     = true
}

variable "enable_rds_vpc_endpoint" {
  description = "Whether to create an interface VPC endpoint for RDS"
  type        = bool
  default     = false
}

variable "enable_bedrock_vpc_endpoint" {
  description = "Whether to create an interface VPC endpoint for Amazon Bedrock"
  type        = bool
  default     = false
}

variable "additional_interface_vpc_endpoints" {
  description = "Additional interface VPC endpoints to create, keyed by short name. See the vpc module for the object shape."
  type = map(object({
    service_name        = string
    private_dns_enabled = optional(bool, true)
  }))
  default = {}
}

# --- Cluster ----------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.33"
}

variable "service_ipv4_cidr" {
  description = "CIDR block for Kubernetes service cluster IPs. Must not overlap vpc_cidr."
  type        = string
  default     = "10.100.0.0/16"
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API server is reachable from outside the VPC"
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks permitted to reach the public API server endpoint. Narrow this in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "authentication_mode" {
  description = "EKS cluster authentication mode: API, CONFIG_MAP, or API_AND_CONFIG_MAP"
  type        = string
  default     = "API"
}

variable "access_entries" {
  description = "IAM principals granted cluster access beyond the creating principal. See the eks module for the object shape."
  type = list(object({
    principal_arn   = string
    username        = string
    groups          = optional(list(string), [])
    access_policies = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"])
  }))
  default = []
}

variable "additional_node_role_arns" {
  description = "Additional EC2 node instance role ARNs needing cluster access, such as a Karpenter node role"
  type        = list(string)
  default     = []
}

# --- Node group -------------------------------------------------------------

variable "node_instance_type" {
  description = "EC2 instance type for the critical node group"
  type        = string
  default     = "t3.large"
}

variable "node_ami_id" {
  description = "AMI ID for the critical node group. Leave empty for the latest Bottlerocket AMI."
  type        = string
  default     = ""
}

variable "bootstrap_type" {
  description = "Node bootstrap style matching the AMI family: BOTTLEROCKET, AL2023, or AMAZONLINUX2"
  type        = string
  default     = "BOTTLEROCKET"
}

variable "node_group_desired_size" {
  description = "Desired number of nodes in the critical node group"
  type        = number
  default     = 2
}

variable "node_group_min_size" {
  description = "Minimum number of nodes in the critical node group"
  type        = number
  default     = 2
}

variable "node_group_max_size" {
  description = "Maximum number of nodes in the critical node group"
  type        = number
  default     = 10
}

variable "node_volume_size" {
  description = "Size in GB of the node data volume"
  type        = number
  default     = 100
}

variable "node_instance_additional_managed_policies" {
  description = "Additional managed policy ARNs for the node instance role"
  type        = list(string)
  default     = []
}

variable "critical_node_labels" {
  description = "Labels on the critical node group. These are a contract with the platform Helm chart; change only alongside matching chart values."
  type        = map(string)
  default = {
    "juliarun/node-class" = "critical"
    "juliarun/schedule"   = "no"
    "juliarun/cpu"        = "prevent_juliarun_jobs"
  }
}

variable "critical_node_taints" {
  description = "Taints on the critical node group"
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  default = [
    {
      key    = "CriticalAddonsOnly"
      value  = "true"
      effect = "NO_SCHEDULE"
    },
  ]
}

variable "enable_karpenter_discovery_tag" {
  description = "Whether to tag the cluster security group for Karpenter discovery"
  type        = bool
  default     = true
}

# --- Addons -----------------------------------------------------------------

variable "cni_version" {
  description = "Version of the vpc-cni addon. Empty selects the latest compatible version."
  type        = string
  default     = ""
}

variable "coredns_version" {
  description = "Version of the coredns addon. Empty selects the latest compatible version."
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy addon. Empty selects the latest compatible version."
  type        = string
  default     = ""
}

variable "ebs_csi_version" {
  description = "Version of the aws-ebs-csi-driver addon. Empty selects the latest compatible version."
  type        = string
  default     = ""
}

variable "efs_csi_version" {
  description = "Version of the aws-efs-csi-driver addon. Empty selects the latest compatible version."
  type        = string
  default     = ""
}

variable "create_default_storage_class" {
  description = "Whether the EBS CSI addon creates a default StorageClass. EKS ships a gp2 class that is neither default nor CSI-backed, so without this any PVC that does not name a class stays Pending. The platform chart's redis StatefulSet needs it."
  type        = bool
  default     = true
}

variable "enable_efs_csi_driver" {
  description = "Whether to install the aws-efs-csi-driver addon. Required by the JuliaHub platform."
  type        = bool
  default     = true
}

# --- Cluster controllers ----------------------------------------------------

variable "create_karpenter_iam" {
  description = <<-EOT
    Whether to create the IAM roles, instance profile, and interruption queue
    Karpenter needs.

    Karpenter itself is installed by Helm from the upstream chart; AWS
    publishes no EKS managed add-on for it. This creates only the AWS-side
    resources that chart expects. Job nodes are provisioned by an autoscaler,
    so leave this enabled unless you run a different one.
  EOT
  type        = bool
  default     = true
}

variable "karpenter_namespace" {
  description = "Namespace Karpenter is installed into"
  type        = string
  default     = "kube-system"
}

variable "karpenter_service_account_name" {
  description = "Name of the Karpenter controller service account"
  type        = string
  default     = "karpenter"
}

variable "karpenter_interruption_queue" {
  description = "Whether to create the SQS queue and EventBridge rules that let Karpenter drain nodes ahead of spot interruption and scheduled maintenance"
  type        = bool
  default     = true
}

variable "create_alb_controller_iam" {
  description = <<-EOT
    Whether to create the IRSA role for the AWS Load Balancer Controller.

    The controller itself is installed by Helm from the upstream chart; AWS
    publishes no EKS managed add-on for it. This creates only the IAM role that
    chart's service account annotates. Required if you expose the platform
    through an ALB Ingress.
  EOT
  type        = bool
  default     = true
}

variable "alb_controller_namespace" {
  description = "Namespace the AWS Load Balancer Controller is installed into"
  type        = string
  default     = "kube-system"
}

variable "alb_controller_service_account_name" {
  description = "Name of the AWS Load Balancer Controller service account"
  type        = string
  default     = "aws-load-balancer-controller"
}

# --- TLS --------------------------------------------------------------------

variable "certificate_arn" {
  description = <<-EOT
    ARN of the ACM certificate the load balancer terminates TLS with.

    Supply one you already have, from an ACM import, an internal CA, or a
    certificate issued out of band. When your parent zone is in Route 53 you can
    instead create one with modules/acm-certificate and pass its output here.

    Surfaced as the alb_ingress_certificate_arn output, which goes on the
    platform chart's websrvr ingress annotation. Leaving it empty means the ALB
    has no certificate and serves HTTP only.
  EOT
  type        = string
  default     = ""
}

# --- Shared filesystems -----------------------------------------------------

variable "create_efs_config_directory" {
  description = "Whether to create the EFS filesystem backing the platform config directory. The platform requires a ReadWriteMany volume here, which on AWS means EFS."
  type        = bool
  default     = true
}

variable "efs_config_directory_backup" {
  description = "Whether to enable AWS Backup on the config directory filesystem. It holds platform state, so backups are recommended."
  type        = bool
  default     = true
}

variable "create_efs_userdata_directory" {
  description = "Whether to create the EFS filesystem backing per-user job storage. Required for jobs with persistent storage."
  type        = bool
  default     = true
}

variable "efs_userdata_transition_to_ia" {
  description = "When userdata files move to Infrequent Access storage. Set to \"none\" to keep everything in Standard."
  type        = string
  default     = "AFTER_14_DAYS"
}

variable "efs_userdata_backup" {
  description = "Whether to enable AWS Backup on the userdata filesystem"
  type        = bool
  default     = false
}

variable "additional_efs_mount_role_arns" {
  description = "Additional IAM role ARNs permitted to mount the EFS filesystems, beyond the cluster node role. Pass the Karpenter node role when job nodes are provisioned by Karpenter, since the CSI daemonset mounts under the node identity."
  type        = list(string)
  default     = []
}

# --- Database ---------------------------------------------------------------

variable "create_rds" {
  description = "Whether to create a PostgreSQL RDS instance for the platform. Set false to use a database you manage separately."
  type        = bool
  default     = true
}

variable "rds_identifier" {
  description = "Identifier for the RDS instance. Defaults to cluster_name."
  type        = string
  default     = ""
}

variable "postgresql_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.m7g.large"
}

variable "rds_database_name" {
  description = "Name of a database to create on the instance. Leave empty to use the default postgres database."
  type        = string
  default     = ""
}

variable "rds_allocated_storage" {
  description = "Initial RDS storage in GB"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Upper bound in GB for RDS storage autoscaling"
  type        = number
  default     = 1000
}

variable "rds_multi_az" {
  description = "Whether to run an RDS standby in a second availability zone"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Days to retain automated RDS backups"
  type        = number
  default     = 30
}

variable "rds_deletion_protection" {
  description = "Whether RDS deletion protection is enabled"
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Whether to skip the final RDS snapshot on destroy"
  type        = bool
  default     = false
}

variable "rds_snapshot_identifier" {
  description = "RDS snapshot identifier to restore from. Leave empty to create a fresh instance."
  type        = string
  default     = ""
}

variable "alarm_sns_topic_arns" {
  description = "SNS topic ARNs notified by the RDS CloudWatch alarms. Leaving this empty creates no alarms."
  type        = list(string)
  default     = []
}

# --- Compute (jobs, datasets, logs) -----------------------------------------

variable "create_compute" {
  description = "Whether to create the compute IAM roles, datasets bucket, and log groups the platform needs to run jobs"
  type        = bool
  default     = true
}

variable "compute_name" {
  description = "Name identifying this install, used to name compute IAM roles and derive bucket names. Defaults to cluster_name; a domain such as juliahub.example.com is typical."
  type        = string
  default     = ""
}

variable "service_account_namespace" {
  description = "Kubernetes namespace the platform is deployed into. Used as the IRSA trust subject."
  type        = string
  default     = "juliahub"
}

variable "service_account_names" {
  description = "Service accounts in the platform namespace permitted to assume the compute IRSA role"
  type        = list(string)
  default     = ["juliahub-platform", "juliarun"]
}

variable "datasets_bucket_name" {
  description = "Name of the datasets bucket. Leave empty to derive it from compute_name."
  type        = string
  default     = ""
}

variable "allowed_origins" {
  description = "Origins permitted to upload directly to the datasets bucket via CORS, without the scheme. Must include the platform hostname. Defaults to compute_name."
  type        = list(string)
  default     = []
}

variable "force_destroy_datasets_bucket" {
  description = "Whether terraform destroy may delete the datasets bucket while it still holds objects. This destroys data."
  type        = bool
  default     = false
}

variable "datasets_bucket_notifications" {
  description = "SQS queues notified on object creation in the datasets bucket, keyed by short name. Use this to hook up object scanning."
  type = map(object({
    queue_arn     = string
    events        = optional(list(string), ["s3:ObjectCreated:*"])
    filter_prefix = optional(string, null)
  }))
  default = {}
}

variable "additional_datasets_bucket_policy_statements" {
  description = "Additional JSON-encoded IAM policy statements merged into the datasets bucket policy"
  type        = list(string)
  default     = []
}

variable "force_destroy_log_buckets" {
  description = "Whether terraform destroy may delete the log archive buckets while they still hold objects"
  type        = bool
  default     = false
}

variable "create_logging" {
  description = "Whether to create the audit and job log groups and their S3 archive buckets"
  type        = bool
  default     = true
}

variable "audit_log_retention_days" {
  description = "Retention in days for the audit log group"
  type        = number
  default     = 30
}

variable "job_log_retention_days" {
  description = "Retention in days for the job log group"
  type        = number
  default     = 7
}

variable "additional_trusted_role_arns" {
  description = "Additional IAM role ARNs permitted to assume the jobs and datasets roles"
  type        = list(string)
  default     = []
}
