variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.33"
}

variable "region" {
  description = "AWS region. Used to construct the STS audience for the OIDC provider."
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC to create the cluster in"
  type        = string
}

variable "control_plane_subnet_ids" {
  description = "Subnet IDs for the EKS control plane ENIs. Must span at least two availability zones."
  type        = list(string)
}

variable "node_group_subnet_ids" {
  description = "Subnet IDs for the critical node group. Normally the private subnets."
  type        = list(string)
}

variable "service_ipv4_cidr" {
  description = "CIDR block from which Kubernetes service cluster IPs are assigned. Must not overlap the VPC CIDR."
  type        = string
  default     = "10.100.0.0/16"
}

variable "endpoint_public_access" {
  description = "Whether the Kubernetes API server is reachable from outside the VPC"
  type        = bool
  default     = true
}

variable "endpoint_public_access_cidrs" {
  description = "CIDR blocks permitted to reach the public Kubernetes API server endpoint. Narrow this from the default in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Control plane log types to ship to CloudWatch Logs. Valid values: api, audit, authenticator, controllerManager, scheduler."
  type        = list(string)
  default     = ["controllerManager", "authenticator", "audit"]
}

variable "authentication_mode" {
  description = "EKS cluster authentication mode. Valid values: API, CONFIG_MAP, API_AND_CONFIG_MAP."
  type        = string
  default     = "API"

  validation {
    condition     = contains(["API", "CONFIG_MAP", "API_AND_CONFIG_MAP"], var.authentication_mode)
    error_message = "authentication_mode must be one of: API, CONFIG_MAP, API_AND_CONFIG_MAP."
  }
}

variable "access_entries" {
  description = <<-EOT
    IAM principals granted access to the cluster, beyond the principal that creates it.

    The creating principal is granted admin automatically via
    bootstrap_cluster_creator_admin_permissions.

    access_entries = [
      {
        principal_arn = "arn:aws:iam::111122223333:role/PlatformAdmin"
        username      = "PlatformAdmin"
      },
    ]

    Optional fields:
    - groups: Kubernetes groups for the access entry (default: [])
    - access_policies: EKS access policy ARNs to attach (default: [AmazonEKSClusterAdminPolicy])
  EOT
  type = list(object({
    principal_arn   = string
    username        = string
    groups          = optional(list(string), [])
    access_policies = optional(list(string), ["arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"])
  }))
  default = []
}

variable "additional_node_role_arns" {
  description = "IAM role ARNs of EC2 node instance roles that need EC2_LINUX access entries, beyond the node role this module creates. Supply the Karpenter node role ARN here when Karpenter provisions nodes."
  type        = list(string)
  default     = []
}

# --- Node group -------------------------------------------------------------

variable "critical_node_instance_type" {
  description = "EC2 instance type for the critical node group"
  type        = string
  default     = "t3.large"
}

variable "critical_node_ami_id" {
  description = "AMI ID for the critical node group. Leave empty to use the latest Bottlerocket AMI matching kubernetes_version."
  type        = string
  default     = ""
}

variable "critical_node_bootstrap_type" {
  description = "Bootstrap style for critical node group nodes, which must match the AMI family in use. Valid values: BOTTLEROCKET, AL2023, AMAZONLINUX2."
  type        = string
  default     = "BOTTLEROCKET"

  validation {
    condition     = contains(["BOTTLEROCKET", "AL2023", "AMAZONLINUX2"], var.critical_node_bootstrap_type)
    error_message = "critical_node_bootstrap_type must be one of: BOTTLEROCKET, AL2023, AMAZONLINUX2."
  }
}

variable "critical_node_group_desired_size" {
  description = "Desired number of nodes in the critical node group"
  type        = number
  default     = 2
}

variable "critical_node_group_min_size" {
  description = "Minimum number of nodes in the critical node group"
  type        = number
  default     = 2
}

variable "critical_node_group_max_size" {
  description = "Maximum number of nodes in the critical node group"
  type        = number
  default     = 10
}

variable "critical_node_volume_size" {
  description = "Size in GB of the data volume on critical node group nodes"
  type        = number
  default     = 100
}

variable "critical_node_additional_managed_policies" {
  description = "Additional managed policy ARNs to attach to the critical node group instance role"
  type        = list(string)
  default     = []
}

variable "critical_node_labels" {
  description = <<-EOT
    Kubernetes labels applied to the critical node group.

    These are a compatibility contract with the JuliaHub platform Helm chart:
    the chart's nodeSelectors, and the managed addon configuration in this
    module, both select on juliarun/node-class. Change these only alongside
    matching chart values.
  EOT
  type        = map(string)
  default = {
    "juliarun/node-class" = "critical"
    "juliarun/schedule"   = "no"
    "juliarun/cpu"        = "prevent_juliarun_jobs"
  }
}

variable "critical_node_taints" {
  description = "Taints applied to the critical node group, keeping general workloads off the nodes that run platform components and addons"
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

variable "addon_node_selector" {
  description = "nodeSelector applied to the managed addon controllers, so they land on the critical node group. Defaults to the juliarun/node-class label from critical_node_labels."
  type        = map(string)
  default = {
    "juliarun/node-class" = "critical"
  }
}

variable "enable_karpenter_discovery_tag" {
  description = "Whether to tag the cluster security group with karpenter.sh/discovery, so Karpenter can discover it. The JuliaHub platform relies on an autoscaler to provision job nodes; leave this enabled when using Karpenter."
  type        = bool
  default     = true
}

variable "launch_template_tags" {
  description = "Additional tags applied to EC2 instances, EBS volumes, and network interfaces created by the node group launch template"
  type        = map(string)
  default     = {}
}

# --- Addons -----------------------------------------------------------------

variable "cni_version" {
  description = "Version of the vpc-cni addon. Leave empty for the latest version compatible with kubernetes_version."
  type        = string
  default     = ""
}

variable "coredns_version" {
  description = "Version of the coredns addon. Leave empty for the latest version compatible with kubernetes_version."
  type        = string
  default     = ""
}

variable "kube_proxy_version" {
  description = "Version of the kube-proxy addon. Leave empty for the latest version compatible with kubernetes_version."
  type        = string
  default     = ""
}

variable "ebs_csi_version" {
  description = "Version of the aws-ebs-csi-driver addon. Leave empty for the latest version compatible with kubernetes_version."
  type        = string
  default     = ""
}

variable "efs_csi_version" {
  description = "Version of the aws-efs-csi-driver addon. Leave empty for the latest version compatible with kubernetes_version. The JuliaHub platform uses EFS for its config and userdata directories, so this addon is required."
  type        = string
  default     = ""
}

variable "create_default_storage_class" {
  description = <<-EOT
    Whether the EBS CSI addon creates a default StorageClass.

    EKS ships a gp2 StorageClass, but it is not marked default and uses the
    in-tree kubernetes.io/aws-ebs provisioner, which Kubernetes removed in
    1.33. Without this, any PersistentVolumeClaim that does not name a class
    stays Pending forever. The platform chart's redis StatefulSet is one such
    claim, so leave this enabled unless you manage storage classes yourself.
  EOT
  type        = bool
  default     = true
}

variable "enable_efs_csi_driver" {
  description = "Whether to install the aws-efs-csi-driver addon and its IRSA role. The JuliaHub platform requires EFS, so leave this enabled unless EFS is managed outside this module."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
