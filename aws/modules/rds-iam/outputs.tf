output "bootstrap_role_arn" {
  description = "ARN of the bootstrap Job's IRSA role. Maps to postgres.external.iam.bootstrapServiceAccountAnnotations[\"eks.amazonaws.com/role-arn\"]."
  value       = aws_iam_role.bootstrap.arn
}

output "provisioner_role_arn" {
  description = "ARN of the create-database-user hook's IRSA role, or null without manage_master_user_password. Maps to postgres.external.iam.provisionerServiceAccountAnnotations[\"eks.amazonaws.com/role-arn\"]."
  value       = one(aws_iam_role.provisioner[*].arn)
}
