variable "platform_hostname" {
  description = "Hostname of the JuliaHub platform. The platform finds the efs-samba launch template by a `juliahub-namespace` tag equal to its hostname, and resource names are derived from it unless resource_name_prefix is set."
  type        = string
}

variable "resource_name_prefix" {
  description = "Prefix for resource names. Defaults to platform_hostname with dots replaced by dashes."
  type        = string
  default     = ""
}

variable "vpc_id" {
  description = "VPC the workstations run in."
  type        = string
}

variable "subnet_id" {
  description = "Private subnet the workstations and their efs-samba sidecars launch into. Must reach the userdata EFS mount targets and have outbound access (NAT or VPC endpoints) for SSM."
  type        = string
}

variable "node_security_group_ids" {
  description = "Security groups of the cluster nodes guacd runs on. They are admitted to the workstations on RDP (3389). For the root module this is the EKS cluster security group, which both the managed node group and Karpenter nodes carry."
  type        = list(string)
}

variable "launcher_role_name" {
  description = "Name of the role the platform launches workstations with: the platform pods' IRSA role (the compute module's service_account_role_name). The platform makes these EC2 and SSM calls with its own credentials, not by assuming compute.cloudhost.aws.roleArn. The EC2, SSM and iam:PassRole permissions the launcher needs are attached to it."
  type        = string
}

variable "ami_name" {
  description = "Name, or name prefix, of the Windows Workstation AMI. The most recent AMI matching it is baked into the launch template; the platform also overrides the image per job by exact AMI name, so the job image's tag in the platform settings must be an AMI name visible to this account."
  type        = string
}

variable "ami_owners" {
  description = "Accounts the Windows Workstation and efs-samba AMIs are shared from. JuliaHub publishes both from 192557667917 and shares them into the customer account on request."
  type        = list(string)
  default     = ["192557667917"]
}

variable "efs_samba_ami_name" {
  description = "Name, or name prefix, of the efs-samba AMI, the Linux sidecar that mounts the user's EFS directory and shares it to the workstation over SMB."
  type        = string
  default     = "efs-samba"
}

variable "launch_template_name" {
  description = "Name of the workstation launch template. The platform's job image URL refers to it as amazonami://<name>. Defaults to winworkstation-<resource name prefix>."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "Instance type baked into the workstation launch template. The platform overrides it per job from the requested resources, so this only matters for launches that do not."
  type        = string
  default     = "m5.large"
}

variable "efs_samba_instance_type" {
  description = "Instance type baked into the efs-samba launch template. The platform overrides it with the efs_samba_instance_type compute setting."
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Size in GiB of the workstation's root volume."
  type        = number
  default     = 250
}

variable "key_name" {
  description = "Optional EC2 key pair for the workstations and sidecars, for break-glass access. The platform sets the Windows credentials itself and does not need one."
  type        = string
  default     = null
}

variable "permissions_boundary_arn" {
  description = "Permissions boundary for the workstation instance role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
