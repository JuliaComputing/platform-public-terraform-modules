# Windows Workstation Module

Creates the AWS resources the JuliaHub platform needs to launch Windows Workstation VMs: each session is an EC2 instance the platform starts from a launch template in this account, outside the cluster, with an `efs-samba` sidecar that shares the user's EFS directory to it over SMB.

## Features

- **Launch templates** for the workstation and its efs-samba sidecar, from AMIs JuliaHub shares into the account. The sidecar's template carries the tags the platform looks it up by.
- **Instance profile** for both VMs: SSM managed-instance access, with parameter reads confined to the platform's `jr*` job parameters.
- **Security groups**: RDP (3389) to the workstations from the cluster nodes guacd runs on, and SMB (445) to the sidecar from the workstations.
- **Launcher permissions** attached to the platform pods' IRSA role, which the platform launches with: `RunInstances`, start/stop/terminate/`GetPasswordData`/`CreateImage` on workstation-tagged instances, `iam:PassRole` for the instance role only, and SSM on `jr*` parameters.

## Usage

```hcl
module "windows_workstation" {
  source = "./modules/windows-workstation"

  platform_hostname       = "juliahub.example.com"
  vpc_id                  = module.vpc.vpc_id
  subnet_id               = module.vpc.private_subnet_ids[0]
  node_security_group_ids = [module.eks.cluster_security_group_id]
  launcher_role_name      = module.compute.service_account_role_name

  ami_name = "WindowsWorkstation-2026-Q2"
}
```

The userdata EFS filesystem must admit the sidecar: add `efs_samba_security_group_id` to its NFS ingress and, when it has a filesystem policy, `instance_role_arn` to its mount roles. The root module does both.

Wire the outputs into the platform settings for the Windows job image (`registry_type: Amazon AMI`):

| Output | Setting |
|--------|---------|
| `launch_template_name` | what `amazonami://__WINDOWS_LAUNCH_TEMPLATE__` resolves to: the chart substitutes it from `windowsWorkstation.launchTemplateName`, which defaults to this module's default name, so set that value only if you changed the name |
| `ami_name` | the image entry's `tag` |

The `efs-samba` AMI needs no configuration: the module uses the newest AMI shared into the account whose name starts with `efs_samba_ami_name` (`efs-samba` by default). Re-apply after a newer build is shared to move the sidecar's launch template onto it.
