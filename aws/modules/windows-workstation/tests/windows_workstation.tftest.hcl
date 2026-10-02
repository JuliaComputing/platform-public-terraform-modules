# Plans the module against a mocked AWS provider, so it runs without
# credentials: `terraform test` from this directory.

mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current
    values = { account_id = "111122223333" }
  }
  override_data {
    target = data.aws_region.current
    values = { name = "us-east-1" }
  }
  override_data {
    target = data.aws_partition.current
    values = { partition = "aws" }
  }
  override_data {
    target = data.aws_ami.workstation
    values = { id = "ami-0workstation", name = "WindowsWorkstation-2026-Q2-20260924" }
  }
  override_data {
    target = data.aws_ami.efs_samba
    values = { id = "ami-0efssamba", name = "efs-samba-20260801" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::111122223333:policy/winworkstation-launcher.example-juliahub-com" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::111122223333:role/winworkstation.example-juliahub-com" }
  }
}

variables {
  platform_hostname       = "example.juliahub.com"
  vpc_id                  = "vpc-0123"
  subnet_id               = "subnet-0123"
  node_security_group_ids = ["sg-0nodes"]
  launcher_role_name      = "juliahub-compute.example-juliahub-com"
  ami_name                = "WindowsWorkstation-2026-Q2"
}

run "defaults" {
  command = plan

  assert {
    condition     = aws_launch_template.workstation.name == "winworkstation-example-juliahub-com"
    error_message = "launch template name should derive from the hostname"
  }

  assert {
    condition     = output.job_image_url == "amazonami://winworkstation-example-juliahub-com"
    error_message = "job image URL should name the launch template without a version, so the default version is used"
  }

  assert {
    condition     = output.ami_name == "WindowsWorkstation-2026-Q2-20260924"
    error_message = "ami_name should be the resolved AMI's exact name, for the job image tag"
  }

  assert {
    condition     = aws_launch_template.workstation.image_id == "ami-0workstation" && aws_launch_template.efs_samba.image_id == "ami-0efssamba"
    error_message = "launch templates should use the resolved AMIs"
  }

  # The platform finds the sidecar's template by tag, not by name.
  assert {
    condition = (
      aws_launch_template.efs_samba.tags["juliahub-winworkstation-app"] == "" &&
      aws_launch_template.efs_samba.tags["juliahub-namespace"] == "example.juliahub.com" &&
      aws_launch_template.efs_samba.tags["juliarun-job-component"] == "efs-samba"
    )
    error_message = "efs-samba launch template must carry the tags the platform looks it up by"
  }

  assert {
    condition     = one(aws_launch_template.workstation.network_interfaces).associate_public_ip_address == "false"
    error_message = "workstations must not get a public IP"
  }

  # Accounts that deny RunInstances without IMDSv2 must still be able to launch both.
  assert {
    condition = (
      one(aws_launch_template.workstation.metadata_options).http_tokens == "required" &&
      one(aws_launch_template.efs_samba.metadata_options).http_tokens == "required"
    )
    error_message = "both launch templates must require IMDSv2"
  }

  # Job parameters for users with long email addresses exceed the Standard tier's 4 KB.
  assert {
    condition = (
      aws_ssm_service_setting.default_parameter_tier[0].setting_value == "Intelligent-Tiering" &&
      aws_ssm_service_setting.default_parameter_tier[0].setting_id == "arn:aws:ssm:us-east-1:111122223333:servicesetting/ssm/parameter-store/default-parameter-tier"
    )
    error_message = "the default parameter tier should be Intelligent-Tiering, in this account and region"
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.workstation_rdp[0].from_port == 3389 && aws_vpc_security_group_ingress_rule.workstation_rdp[0].referenced_security_group_id == "sg-0nodes"
    error_message = "RDP should be admitted only from the node security groups"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.launcher.role == "juliahub-compute.example-juliahub-com"
    error_message = "launcher permissions should attach to the launcher role"
  }
}

# Applied (against the mock) because the policy embeds the instance role ARN,
# which is unknown at plan time.
run "launcher_policy_is_scoped" {
  command = apply

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.launcher.policy).Statement :
      s.Resource == "arn:aws:iam::111122223333:role/winworkstation.example-juliahub-com"
      if s.Action == "iam:PassRole"
    ])
    error_message = "iam:PassRole should be limited to the workstation instance role"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.launcher.policy).Statement :
      s.Resource == "arn:aws:ssm:us-east-1:111122223333:parameter/jr*"
      if s.Sid == "JobParameters"
    ])
    error_message = "SSM access should be limited to the platform's jr* job parameters"
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_policy.launcher.policy).Statement :
      s.Condition.StringEquals["aws:ResourceTag/juliarun-job-type"] == "windows-workstation"
      if s.Sid == "ManageWorkstations"
    ])
    error_message = "instance start/stop/terminate should be limited to workstation-tagged instances"
  }
}

run "explicit_launch_template_name" {
  command = plan

  variables {
    launch_template_name = "custom-winworkstation"
  }

  assert {
    condition     = output.job_image_url == "amazonami://custom-winworkstation" && aws_launch_template.efs_samba.name == "custom-winworkstation-efs-samba"
    error_message = "an explicit launch template name should carry through to both templates and the URL"
  }
}

run "parameter_tier_opt_out" {
  command = plan

  variables {
    intelligent_parameter_tiering = false
  }

  assert {
    condition     = length(aws_ssm_service_setting.default_parameter_tier) == 0
    error_message = "turning intelligent_parameter_tiering off should leave the account's setting alone"
  }
}
