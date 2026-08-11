output "service_account_role_arn" {
  description = "ARN of the IRSA role for the platform service accounts. Set this as the eks.amazonaws.com/role-arn annotation via the chart's serviceAccount.annotations value."
  value       = aws_iam_role.service_account.arn
}

output "service_account_role_name" {
  description = "Name of the platform IRSA role"
  value       = aws_iam_role.service_account.name
}

output "jobs_role_arn" {
  description = "ARN of the role jobs assume for log and secret access"
  value       = aws_iam_role.jobs.arn
}

output "datasets_role_arn" {
  description = "ARN of the role assumed for dataset access. Maps to the platform's compute.storage.aws.storageRoleArn Helm value."
  value       = aws_iam_role.datasets.arn
}

output "job_outputs_role_arn" {
  description = "ARN of the role the job runner assumes to issue scoped credentials for result uploads"
  value       = aws_iam_role.job_outputs.arn
}

output "datasets_bucket_name" {
  description = "Name of the datasets bucket. Maps to the platform's compute.storage.aws.bucketName Helm value."
  value       = local.datasets_bucket_name
}

output "datasets_bucket_arn" {
  description = "ARN of the datasets bucket"
  value       = local.datasets_bucket_arn
}

output "audit_log_group_name" {
  description = "Name of the audit log group, or null when logging is disabled"
  value       = local.create_logging ? aws_cloudwatch_log_group.audit[0].name : null
}

output "job_log_group_name" {
  description = "Name of the job log group, or null when logging is disabled"
  value       = local.create_logging ? aws_cloudwatch_log_group.jobs[0].name : null
}

output "audit_log_archive_bucket_name" {
  description = "Name of the audit log archive bucket, or null when logging is disabled"
  value       = local.create_logging ? aws_s3_bucket.log_archive["audit"].bucket : null
}

output "job_log_archive_bucket_name" {
  description = "Name of the job log archive bucket, or null when logging is disabled"
  value       = local.create_logging ? aws_s3_bucket.log_archive["jobs"].bucket : null
}
