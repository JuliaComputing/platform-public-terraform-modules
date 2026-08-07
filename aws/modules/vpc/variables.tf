variable "cluster_name" {
  description = "Name of the EKS cluster this VPC hosts. Used for resource naming and for the karpenter.sh/discovery tag on private subnets."
  type        = string
}

variable "vpc_cidr" {
  description = "Primary CIDR block for the VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "additional_vpc_cidrs" {
  description = "Additional CIDR blocks to associate with the VPC. These must follow https://docs.aws.amazon.com/vpc/latest/userguide/vpc-cidr-blocks.html#add-cidr-block-restrictions"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets. One subnet is created per entry."
  type        = list(string)
  default = [
    "192.168.0.0/18",
    "192.168.64.0/18",
  ]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets. One subnet is created per entry. EKS nodes run here."
  type        = list(string)
  default = [
    "192.168.128.0/18",
    "192.168.192.0/18",
  ]
}

variable "availability_zones" {
  description = "Availability zones to distribute subnets across. Must contain at least as many zones as there are private subnet CIDRs. EKS requires at least two."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1c"]
}

variable "dhcp_option_domain" {
  description = "Domain name of an existing DHCP option set to associate with the VPC. Set to an empty string to skip the association and use the VPC default."
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region. Used to construct VPC endpoint service names."
  type        = string
  default     = "us-east-1"
}

variable "nat_gateway_ids" {
  description = "IDs of existing NAT gateways to use for outbound traffic from private subnets. Leave empty to have the module create one NAT gateway per public subnet. Supply these when outbound traffic must route through a network firewall managed outside this module."
  type        = list(string)
  default     = []
}

variable "map_public_ip_on_launch" {
  description = "Whether instances launched into the public subnets receive a public IP address"
  type        = bool
  default     = true
}

variable "enable_ecr_vpc_endpoint" {
  description = "Whether to create an interface VPC endpoint for ECR (com.amazonaws.<region>.ecr.dkr), so nodes can pull images without traversing the NAT gateway"
  type        = bool
  default     = true
}

variable "enable_rds_vpc_endpoint" {
  description = "Whether to create an interface VPC endpoint for RDS. Only useful when the platform database is an RDS instance reached over PrivateLink."
  type        = bool
  default     = false
}

variable "enable_s3_vpc_endpoint" {
  description = "Whether to create a gateway VPC endpoint for S3 and associate it with the public and private route tables"
  type        = bool
  default     = true
}

variable "enable_s3_global_vpc_endpoint" {
  description = "Whether to create an interface VPC endpoint for S3 multi-region access points (com.amazonaws.s3-global.accesspoint)"
  type        = bool
  default     = false
}

variable "enable_bedrock_vpc_endpoint" {
  description = "Whether to create an interface VPC endpoint for Amazon Bedrock, so workloads can invoke Bedrock models without traversing the public internet"
  type        = bool
  default     = false
}

variable "additional_interface_vpc_endpoints" {
  description = <<-EOT
    Additional interface VPC endpoints to create, keyed by a short name used in the resource address and Name tag.

    Use this for PrivateLink services that are specific to your environment, for example a vendor-hosted API reached over an endpoint service.

    additional_interface_vpc_endpoints = {
      "example-api" = {
        service_name        = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
        private_dns_enabled = true
      }
    }
  EOT
  type = map(object({
    service_name        = string
    private_dns_enabled = optional(bool, true)
  }))
  default = {}
}

variable "vpc_endpoint_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the interface VPC endpoints on port 443. Defaults to the VPC CIDR so only in-VPC traffic is permitted."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
