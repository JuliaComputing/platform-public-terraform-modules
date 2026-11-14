output "identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance._.identifier
}

output "arn" {
  description = "ARN of the RDS instance"
  value       = aws_db_instance._.arn
}

output "address" {
  description = "Hostname of the RDS instance. Maps to the platform's postgres.host Helm value."
  value       = aws_db_instance._.address
}

output "port" {
  description = "Port the instance listens on. Maps to the platform's postgres.port Helm value."
  value       = aws_db_instance._.port
}

output "username" {
  description = "Master username. Maps to the platform's postgres.username Helm value."
  value       = aws_db_instance._.username
}

output "password" {
  description = "Generated master password. Null when restoring from a snapshot, since the snapshot carries its own credentials, and with manage_master_user_password, where it is in the master_user_secret_arn secret."
  value       = one(random_password.master[*].result)
  sensitive   = true
}

output "database_name" {
  description = "Name of the database created on the instance, if any"
  value       = aws_db_instance._.db_name
}

output "engine_version" {
  description = "Running PostgreSQL engine version"
  value       = aws_db_instance._.engine_version
}

output "security_group_id" {
  description = "ID of the security group controlling access to the instance. Add ingress rules here, or pass allow_from_security_group_ids."
  value       = aws_security_group._.id
}

output "connection_string" {
  description = "PostgreSQL connection string for the instance"
  value = local.generate_password ? format(
    "postgresql://%s:%s@%s:%s/%s?sslmode=require",
    aws_db_instance._.username,
    random_password.master[0].result,
    aws_db_instance._.address,
    aws_db_instance._.port,
    var.database_name == "" ? "postgres" : var.database_name,
  ) : null
  sensitive = true
}

output "resource_id" {
  description = "The instance's DbiResourceId, the resource part of an rds-db:connect ARN"
  value       = aws_db_instance._.resource_id
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS-managed master credentials, a JSON object with username and password. Null unless manage_master_user_password is set. Maps to postgres.external.iam.masterUserSecretArn."
  value       = local.master_user_secret_arn
}

output "master_user_secret_read_policy_json" {
  description = "IAM policy document allowing reads of the master user secret, or null unless manage_master_user_password is set. Attach it only to the role of the chart's create-database-user hook, not to the platform services."
  value       = one(data.aws_iam_policy_document.master_user_secret_read[*].json)
}

output "iam_database_authentication_enabled" {
  description = "Whether IAM database authentication is enabled on the instance"
  value       = aws_db_instance._.iam_database_authentication_enabled
}

output "iam_db_username" {
  description = "Database role the platform services connect as with IAM authentication. Maps to postgres.external.username."
  value       = var.iam_db_username
}

output "iam_admin_db_username" {
  description = "Database role the bootstrap Job connects as with IAM authentication. Maps to postgres.external.iam.adminUsername."
  value       = var.iam_admin_db_username
}

output "iam_connect_policy_json" {
  description = "IAM policy document allowing rds-db:connect as iam_db_username, or null unless iam_database_authentication_enabled is set. Attach it to the platform service account role."
  value       = one(data.aws_iam_policy_document.iam_connect[*].json)
}

output "iam_admin_connect_policy_json" {
  description = "IAM policy document allowing rds-db:connect as iam_admin_db_username, or null unless iam_database_authentication_enabled is set. Attach it only to the bootstrap Job's role."
  value       = one(data.aws_iam_policy_document.iam_admin_connect[*].json)
}
