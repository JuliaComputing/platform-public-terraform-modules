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

locals {
  create_vpc = var.vpc_id == null

  vpc_id             = local.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  private_subnet_ids = local.create_vpc ? module.vpc[0].private_subnet_ids : var.private_subnet_ids
  public_subnet_ids  = local.create_vpc ? module.vpc[0].public_subnet_ids : var.public_subnet_ids
  # The EKS control plane places ENIs in both public and private subnets.
  all_subnet_ids = local.create_vpc ? module.vpc[0].subnet_ids : concat(var.private_subnet_ids, var.public_subnet_ids)
}

module "vpc" {
  # Gated on vpc_id rather than the subnet lists: count must be known at plan
  # time, and a caller may legitimately compute subnet IDs from another module.
  count  = local.create_vpc ? 1 : 0
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

  vpc_id = local.vpc_id
  # The control plane places ENIs in both public and private subnets; nodes run
  # only in the private subnets.
  control_plane_subnet_ids = local.all_subnet_ids
  node_group_subnet_ids    = local.private_subnet_ids

  service_ipv4_cidr            = var.service_ipv4_cidr
  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  authentication_mode          = var.authentication_mode

  access_entries = var.access_entries
  # Karpenter nodes need an access entry to register with the cluster. The role
  # is created by the karpenter module below, so it is passed as a variable
  # rather than a module reference to avoid a dependency cycle.
  additional_node_role_arns = var.additional_node_role_arns

  critical_node_instance_type      = var.critical_node_instance_type
  critical_node_ami_id             = var.critical_node_ami_id
  critical_node_bootstrap_type     = var.critical_node_bootstrap_type
  critical_node_group_desired_size = var.critical_node_group_desired_size
  critical_node_group_min_size     = var.critical_node_group_min_size
  critical_node_group_max_size     = var.critical_node_group_max_size
  critical_node_volume_size        = var.critical_node_volume_size

  critical_node_additional_managed_policies = var.critical_node_additional_managed_policies

  critical_node_labels = var.critical_node_labels
  critical_node_taints = var.critical_node_taints

  cni_version           = var.cni_version
  coredns_version       = var.coredns_version
  kube_proxy_version    = var.kube_proxy_version
  ebs_csi_version       = var.ebs_csi_version
  efs_csi_version       = var.efs_csi_version
  enable_efs_csi_driver = var.enable_efs_csi_driver

  create_default_storage_class = var.create_default_storage_class

  enable_karpenter_discovery_tag = var.enable_karpenter_discovery_tag

  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = local.common_tags
}

module "rds" {
  source = "./modules/rds"
  count  = var.create_rds ? 1 : 0

  identifier         = var.rds_identifier == "" ? var.cluster_name : var.rds_identifier
  postgresql_version = var.postgresql_version
  instance_class     = var.rds_instance_class
  database_name      = var.rds_database_name

  allocated_storage     = var.rds_allocated_storage
  max_allocated_storage = var.rds_max_allocated_storage
  multi_az              = var.rds_multi_az

  subnet_ids = local.private_subnet_ids
  # Only workloads in the cluster reach the database.
  allow_from_security_group_ids = [module.eks.cluster_security_group_id]

  backup_retention_period = var.rds_backup_retention_period
  deletion_protection     = var.rds_deletion_protection
  skip_final_snapshot     = var.rds_skip_final_snapshot
  snapshot_identifier     = var.rds_snapshot_identifier

  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = local.common_tags
}

module "karpenter" {
  source = "./modules/karpenter"
  count  = var.create_karpenter_iam ? 1 : 0

  cluster_name = module.eks.cluster_name
  # Passed through rather than looked up: the cluster is created in this same
  # apply, so a data lookup would fail at plan time.
  lookup_cluster       = false
  oidc_provider        = module.eks.oidc_provider
  namespace            = var.karpenter_namespace
  service_account_name = var.karpenter_service_account_name

  create_interruption_queue = var.karpenter_interruption_queue

  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = local.common_tags
}

module "alb_controller" {
  source = "./modules/alb-controller"
  count  = var.create_alb_controller_iam ? 1 : 0

  cluster_name = module.eks.cluster_name
  # Passed through rather than looked up: the cluster is created in this same
  # apply, so a data lookup would fail at plan time.
  lookup_cluster       = false
  oidc_provider        = module.eks.oidc_provider
  namespace            = var.alb_controller_namespace
  service_account_name = var.alb_controller_service_account_name

  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = local.common_tags
}

locals {
  # Karpenter-provisioned nodes must be able to join the cluster and mount EFS,
  # both of which key off the node role rather than any pod identity.
  karpenter_node_role_arns = var.create_karpenter_iam ? [module.karpenter[0].node_role_arn] : []

  efs_mount_role_arns = concat(
    [module.eks.node_role_arn],
    local.karpenter_node_role_arns,
    var.additional_efs_mount_role_arns,
  )
}

module "efs_config" {
  source = "./modules/efs"
  count  = var.create_efs_config_directory ? 1 : 0

  name    = var.cluster_name
  purpose = "config"

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  # Only workloads in the cluster mount the filesystem.
  allow_from_security_group_ids = [module.eks.cluster_security_group_id]
  # The CSI node daemonset mounts under the node identity.
  restrict_mount_to_role_arns = var.restrict_efs_mounts_to_node_roles ? local.efs_mount_role_arns : []

  # The config directory is read continually, so IA tiering costs more than it saves.
  transition_to_ia     = "none"
  enable_backup_policy = var.efs_config_directory_backup

  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  tags = local.common_tags
}

module "efs_userdata" {
  source = "./modules/efs"
  count  = var.create_efs_userdata_directory ? 1 : 0

  name    = var.cluster_name
  purpose = "userdata"

  vpc_id     = local.vpc_id
  subnet_ids = local.private_subnet_ids

  allow_from_security_group_ids = [module.eks.cluster_security_group_id]
  restrict_mount_to_role_arns   = var.restrict_efs_mounts_to_node_roles ? local.efs_mount_role_arns : []

  transition_to_ia     = var.efs_userdata_transition_to_ia
  enable_backup_policy = var.efs_userdata_backup

  alarm_sns_topic_arns = var.alarm_sns_topic_arns

  tags = local.common_tags
}

module "compute" {
  source = "./modules/compute"
  count  = var.create_compute ? 1 : 0

  platform_hostname    = var.platform_hostname == "" ? var.cluster_name : var.platform_hostname
  resource_name_prefix = var.resource_name_prefix
  cluster_name         = module.eks.cluster_name
  # Passed through rather than looked up: the cluster is created in this same
  # apply, so a data lookup would fail at plan time.
  lookup_cluster = false
  oidc_provider  = module.eks.oidc_provider

  service_account_namespace = var.service_account_namespace
  service_account_names     = var.service_account_names

  datasets_bucket_name          = var.datasets_bucket_name
  allowed_origins               = var.allowed_origins
  force_destroy_datasets_bucket = var.force_destroy_datasets_bucket

  datasets_bucket_notifications                = var.datasets_bucket_notifications
  additional_datasets_bucket_policy_statements = var.additional_datasets_bucket_policy_statements

  create_logging            = var.create_logging
  force_destroy_log_buckets = var.force_destroy_log_buckets
  audit_log_retention_days  = var.audit_log_retention_days
  job_log_retention_days    = var.job_log_retention_days

  additional_trusted_role_arns = var.additional_trusted_role_arns

  permissions_boundary_arn = var.permissions_boundary_arn
  tags                     = local.common_tags
}
