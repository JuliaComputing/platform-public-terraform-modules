terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

locals {
  common_tags = merge(
    var.tags,
    {
      ManagedBy = "Terraform"
      Project   = "JuliaHub"
    }
  )
}

module "vpc" {
  source = "./modules/vpc"

  cluster_name = var.cluster_name
  region       = var.region

  vpc_cidr             = var.vpc_cidr
  additional_vpc_cidrs = var.additional_vpc_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones

  nat_gateway_ids         = var.nat_gateway_ids
  map_public_ip_on_launch = var.map_public_ip_on_launch

  enable_ecr_vpc_endpoint            = var.enable_ecr_vpc_endpoint
  enable_s3_vpc_endpoint             = var.enable_s3_vpc_endpoint
  enable_rds_vpc_endpoint            = var.enable_rds_vpc_endpoint
  enable_bedrock_vpc_endpoint        = var.enable_bedrock_vpc_endpoint
  additional_interface_vpc_endpoints = var.additional_interface_vpc_endpoints

  tags = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  region             = var.region

  vpc_id = module.vpc.vpc_id
  # The control plane places ENIs in both public and private subnets; nodes run
  # only in the private subnets.
  control_plane_subnet_ids = module.vpc.subnet_ids
  node_group_subnet_ids    = module.vpc.private_subnet_ids

  service_ipv4_cidr            = var.service_ipv4_cidr
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  authentication_mode          = var.authentication_mode

  access_entries            = var.access_entries
  additional_node_role_arns = var.additional_node_role_arns

  node_instance_type      = var.node_instance_type
  node_ami_id             = var.node_ami_id
  bootstrap_type          = var.bootstrap_type
  node_group_desired_size = var.node_group_desired_size
  node_group_min_size     = var.node_group_min_size
  node_group_max_size     = var.node_group_max_size
  node_volume_size        = var.node_volume_size

  node_instance_additional_managed_policies = var.node_instance_additional_managed_policies

  critical_node_labels = var.critical_node_labels
  critical_node_taints = var.critical_node_taints

  cni_version           = var.cni_version
  coredns_version       = var.coredns_version
  kube_proxy_version    = var.kube_proxy_version
  ebs_csi_version       = var.ebs_csi_version
  efs_csi_version       = var.efs_csi_version
  enable_efs_csi_driver = var.enable_efs_csi_driver

  enable_karpenter_discovery_tag = var.enable_karpenter_discovery_tag

  tags = local.common_tags
}
