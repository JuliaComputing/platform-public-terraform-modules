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
  description = "Generated master password. Null when restoring from a snapshot, since the snapshot carries its own credentials."
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
  value = local.restoring_from_snapshot ? null : format(
    "postgresql://%s:%s@%s:%s/%s?sslmode=require",
    aws_db_instance._.username,
    random_password.master[0].result,
    aws_db_instance._.address,
    aws_db_instance._.port,
    var.database_name == "" ? "postgres" : var.database_name,
  )
  sensitive = true
}
