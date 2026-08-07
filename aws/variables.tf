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

variable "enable_efs_csi_driver" {
  description = "Whether to install the aws-efs-csi-driver addon. Required by the JuliaHub platform."
  type        = bool
  default     = true
}
