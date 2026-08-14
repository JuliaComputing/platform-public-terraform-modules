# Networking outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "region" {
  description = "AWS region the infrastructure was created in. Convenient for follow-up CLI calls such as aws eks update-kubeconfig."
  value       = var.region
}

# Cluster outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint of the Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane"
  value       = module.eks.cluster_version
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded certificate authority data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.eks.cluster_security_group_id
}

# IRSA outputs
output "oidc_provider" {
  description = "OIDC issuer hostname and path, for IRSA trust policy conditions"
  value       = module.eks.oidc_provider
}

output "oidc_provider_arn" {
  description = "ARN of the cluster IAM OIDC provider, for IRSA trust policies"
  value       = module.eks.oidc_provider_arn
}

output "node_role_arn" {
  description = "ARN of the node instance role"
  value       = module.eks.node_role_arn
}

output "critical_node_tolerations_helm_set" {
  description = "Tolerations for the critical node group as helm --set arguments. Pass these to the Karpenter and load balancer controller installs, or their pods stay Pending."
  value       = module.eks.critical_node_tolerations_helm_set
}

output "critical_node_tolerations" {
  description = "Tolerations for the critical node group in Kubernetes form"
  value       = module.eks.critical_node_tolerations
}

# TLS outputs
output "alb_ingress_certificate_arn" {
  description = "Certificate ARN for the platform chart's websrvr.ingress.annotations[\"alb.ingress.kubernetes.io/certificate-arn\"]. The load balancer controller attaches it to the ALB listener."
  value       = var.certificate_arn
}

# Controller outputs
output "karpenter_controller_role_arn" {
  description = "Karpenter controller IRSA role ARN. Set as serviceAccount.annotations[\"eks.amazonaws.com/role-arn\"] on the Karpenter chart."
  value       = one(module.karpenter[*].controller_role_arn)
}

output "karpenter_node_role_name" {
  description = "Karpenter node role name. Goes in the EC2NodeClass role field."
  value       = one(module.karpenter[*].node_role_name)
}

output "karpenter_node_role_arn" {
  description = "Karpenter node role ARN. Already wired into the cluster access entries and the EFS mount policy by this module."
  value       = one(module.karpenter[*].node_role_arn)
}

output "karpenter_interruption_queue_name" {
  description = "Karpenter interruption queue name. Set as the chart's settings.interruptionQueue value."
  value       = one(module.karpenter[*].interruption_queue_name)
}

output "alb_controller_role_arn" {
  description = "AWS Load Balancer Controller IRSA role ARN. Set as serviceAccount.annotations[\"eks.amazonaws.com/role-arn\"] on that chart."
  value       = one(module.alb_controller[*].iam_role_arn)
}

output "efs_mounts_require_iam" {
  description = <<-EOT
    Whether EFS mounts must authenticate with the `iam` mount option.

    True when a filesystem policy restricting mounts to the node roles is
    attached, since that removes the EFS default of granting access to any
    client reaching a mount target. Maps to the chart's
    configDirectory.efs.useIAM and compute.userdataDirectory.efs.useIAM, which
    must both be set to this value or the mounts fail with
    `access denied by server`.
  EOT
  value       = var.restrict_efs_mounts_to_node_roles
}

# Shared filesystem outputs
output "config_directory_efs_filesystem_id" {
  description = "EFS filesystem ID for the config directory. Maps to configDirectory.efs.filesystemId."
  value       = one(module.efs_config[*].filesystem_id)
}

output "config_directory_efs_access_point_id" {
  description = "EFS access point ID for the config directory. Maps to configDirectory.efs.accessPointId."
  value       = one(module.efs_config[*].access_point_id)
}

output "userdata_directory_efs_filesystem_id" {
  description = "EFS filesystem ID for per-user job storage. Maps to compute.userdataDirectory.efs.filesystemId."
  value       = one(module.efs_userdata[*].filesystem_id)
}

output "userdata_directory_efs_access_point_id" {
  description = "EFS access point ID for per-user job storage. Maps to compute.userdataDirectory.efs.accessPointId, which is required for this directory."
  value       = one(module.efs_userdata[*].access_point_id)
}

# Database outputs
output "postgres_host" {
  description = "RDS hostname, or null when create_rds is false. Maps to the platform's postgres.host Helm value."
  value       = one(module.rds[*].address)
}

output "postgres_port" {
  description = "RDS port, or null when create_rds is false"
  value       = one(module.rds[*].port)
}

output "postgres_username" {
  description = "RDS master username, or null when create_rds is false"
  value       = one(module.rds[*].username)
}

output "postgres_password" {
  description = "Generated RDS master password, or null when create_rds is false"
  value       = one(module.rds[*].password)
  sensitive   = true
}

# Compute outputs
output "compute_service_account_role_arn" {
  description = "IRSA role ARN for the platform service accounts. Set this via the chart's serviceAccount.annotations value."
  value       = one(module.compute[*].service_account_role_arn)
}

output "datasets_bucket_name" {
  description = "Datasets bucket name. Maps to the platform's compute.storage.aws.bucketName Helm value."
  value       = one(module.compute[*].datasets_bucket_name)
}

output "datasets_role_arn" {
  description = "Datasets role ARN. Maps to the platform's compute.storage.aws.storageRoleArn Helm value."
  value       = one(module.compute[*].datasets_role_arn)
}

output "jobs_role_arn" {
  description = "ARN of the role jobs assume for log and secret access. Maps to compute.cloudhost.aws.roleArn."
  value       = one(module.compute[*].jobs_role_arn)
}

output "cloudhost_max_session_duration" {
  description = "Maximum STS session duration on the jobs role. Must match compute.cloudhost.aws.maxSessionDuration."
  value       = one(module.compute[*].jobs_role_max_session_duration)
}

output "job_outputs_role_arn" {
  description = "ARN of the role used to issue scoped credentials for job result uploads"
  value       = one(module.compute[*].job_outputs_role_arn)
}

output "audit_log_group_name" {
  description = "Name of the audit log group"
  value       = one(module.compute[*].audit_log_group_name)
}

output "job_log_group_name" {
  description = "Name of the job log group"
  value       = one(module.compute[*].job_log_group_name)
}

# Convenience
output "kubeconfig_command" {
  description = "Command to add this cluster to your local kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    region             = var.region
    vpc_id             = module.vpc.vpc_id
    cluster_name       = module.eks.cluster_name
    cluster_version    = module.eks.cluster_version
    cluster_endpoint   = module.eks.cluster_endpoint
    private_subnet_ids = module.vpc.private_subnet_ids
    node_group_name    = module.eks.node_group_name
  }
}
