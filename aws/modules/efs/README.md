# EFS Module

Creates an EFS filesystem, access point, and mount targets for one of the two shared directories the JuliaHub Platform needs on AWS.

Instantiate it twice — once per `purpose`.

## Why EFS

The platform's config directory is mounted read-write by every component at once, so it must be a `ReadWriteMany` volume. On AWS that means EFS; EBS cannot do it. Per-user job storage has the same requirement, since jobs on different nodes mount the same filesystem.

## Purposes

| `purpose` | Backs | Access point path | POSIX user | IA tiering default |
|-----------|-------|-------------------|-----------|--------------------|
| `config` | `configDirectory` | `/config` | not pinned | `none` |
| `userdata` | `compute.userdataDirectory` | `/data` | uid/gid 8000 | `AFTER_14_DAYS` |

The config directory is written by many components under their own users, so its access point does not pin a POSIX identity. Userdata is mounted into job containers, which run as a fixed uid and gid, so its access point pins both — and the chart **requires** an access point ID for userdata, because per-job volumes are derived from the filesystem and access point pair.

The config directory defaults to no IA tiering. It serves package tarballs on demand, so its whole contents are read continually; tiering adds per-access charges without a meaningful storage saving. Userdata has a colder access pattern and does benefit.

## Usage

```hcl
module "efs_config" {
  source = "./modules/efs"

  name    = "juliahub"
  purpose = "config"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  allow_from_security_group_ids = [module.eks.cluster_security_group_id]
  restrict_mount_to_role_arns   = [module.eks.node_role_arn]

  enable_backup_policy = true

  tags = {
    Environment = "production"
  }
}
```

Wire the outputs into the platform chart:

```yaml
configDirectory:
  type: efs
  efs:
    filesystemId: <filesystem_id>
    accessPointId: <access_point_id>
    useIAM: true   # when restrict_mount_to_role_arns is set

compute:
  userdataDirectory:
    type: efs
    efs:
      filesystemId: <filesystem_id>
      accessPointId: <access_point_id>
```

No `StorageClass` is needed. The chart creates the PV and PVC directly against the EFS CSI driver, which the `eks` module installs.

## Network access

Ingress is closed by default. Grant it with `allow_from_security_group_ids`, passing the EKS cluster security group so cluster workloads can mount. `allow_from_cidr_blocks` is available for access from outside the cluster.

Mount targets are created one per availability zone across the subnets you pass. Passing several subnets in the same zone is fine; the module picks one per zone, since EFS permits no more.

## Restricting who can mount

`restrict_mount_to_role_arns` attaches a filesystem policy allowing only the named principals to mount, and denying everyone else. Pass the **node** role: the EFS CSI node daemonset performs the mount under the node identity, not the pod's IRSA role.

When Karpenter provisions job nodes, its node role must be included as well or job pods will fail to mount:

```hcl
restrict_mount_to_role_arns = [
  module.eks.node_role_arn,
  aws_iam_role.karpenter_node.arn,
]
```

Leaving the list empty attaches no policy, so access rests on security groups alone. When it is set, also set `useIAM: true` on the chart's config directory so the CSI driver mounts with IAM authorization.

`enforce_in_transit_encryption` additionally denies any access that does not use TLS.

## Backups

`enable_backup_policy` turns on AWS Backup with the default EFS plan. The root module enables it for the config directory, which holds platform state, and leaves it off for userdata.

## Inputs

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults.

## Outputs

| Output | Description |
|--------|-------------|
| `filesystem_id` | Filesystem ID, for the chart's `filesystemId` |
| `filesystem_arn` | Filesystem ARN |
| `access_point_id` | Access point ID, for the chart's `accessPointId` |
| `access_point_arn` | Access point ARN |
| `volume_handle` | `filesystem::accesspoint` handle for a statically provisioned PV |
| `security_group_id` | Security group controlling NFS access |
| `dns_name` | Filesystem DNS name |
| `mount_target_ids` | Mount target IDs, one per availability zone |
