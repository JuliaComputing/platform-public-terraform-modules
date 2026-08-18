output "filesystem_id" {
  description = "ID of the EFS filesystem. Maps to the chart's configDirectory.efs.filesystemId or compute.userdataDirectory.efs.filesystemId."
  value       = aws_efs_file_system._.id
}

output "filesystem_arn" {
  description = "ARN of the EFS filesystem"
  value       = aws_efs_file_system._.arn
}

output "access_point_id" {
  description = "ID of the access point. Maps to the chart's configDirectory.efs.accessPointId or compute.userdataDirectory.efs.accessPointId."
  value       = aws_efs_access_point._.id
}

output "access_point_arn" {
  description = "ARN of the access point"
  value       = aws_efs_access_point._.arn
}

output "volume_handle" {
  description = "Volume handle the EFS CSI driver uses for a statically provisioned PV, in filesystem::accesspoint form"
  value       = "${aws_efs_file_system._.id}::${aws_efs_access_point._.id}"
}

output "security_group_id" {
  description = "ID of the security group controlling NFS access to the filesystem"
  value       = aws_security_group._.id
}

output "dns_name" {
  description = "DNS name of the filesystem"
  value       = aws_efs_file_system._.dns_name
}

output "mount_target_ids" {
  description = "IDs of the mount targets, one per availability zone"
  value       = aws_efs_mount_target._[*].id
}
