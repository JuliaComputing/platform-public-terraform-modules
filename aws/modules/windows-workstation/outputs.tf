output "launch_template_name" {
  description = "Name of the workstation launch template."
  value       = aws_launch_template.workstation.name
}

output "job_image_url" {
  description = "URL for the Windows Workstation job image in the platform settings (registry_type \"Amazon AMI\"). Versionless, so each launch uses the launch template's default version."
  value       = "amazonami://${aws_launch_template.workstation.name}"
}

output "ami_name" {
  description = "Exact name of the AMI the launch template was built from. Use it as the job image entry's tag."
  value       = data.aws_ami.workstation.name
}

output "instance_role_arn" {
  description = "Role the workstations and efs-samba sidecars run as. The efs-samba sidecar mounts the userdata EFS under it, so an EFS filesystem policy must admit it."
  value       = aws_iam_role.instance.arn
}

output "workstation_security_group_id" {
  description = "Security group of the workstation VMs."
  value       = aws_security_group.workstation.id
}

output "efs_samba_security_group_id" {
  description = "Security group of the efs-samba sidecars. The userdata EFS mount targets must admit it on NFS (2049)."
  value       = aws_security_group.efs_samba.id
}
