# EKS Module

Creates an EKS cluster configured for hosting the JuliaHub Platform.

## Features

- **Access entries** (`authentication_mode = "API"`) rather than the `aws-auth` ConfigMap
- **IAM OIDC provider** for IRSA, with `oidc_provider` and `oidc_provider_arn` outputs
- **Critical node group** running Bottlerocket by default, for platform components and addons
- **Managed addons**: `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`
- **Per-addon IRSA roles**, each trust-scoped to a single service account
- **Karpenter discovery tag** on the cluster security group

## Default Configuration

- **Kubernetes version**: 1.33
- **Node AMI**: latest Bottlerocket matching the Kubernetes version
- **Node instance type**: t3.large
- **Node group size**: 2 desired, 2 min, 10 max
- **Node data volume**: 100 GB gp3, encrypted
- **IMDS**: IMDSv2 required, hop limit 1

## Usage

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name       = "juliahub"
  kubernetes_version = "1.33"
  region             = "us-east-1"

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.subnet_ids
  node_group_subnet_ids    = module.vpc.private_subnet_ids

  access_entries = [
    {
      principal_arn = "arn:aws:iam::111122223333:role/PlatformAdmin"
      username      = "PlatformAdmin"
    },
  ]

  tags = {
    Environment = "production"
  }
}
```

## Node labels are a chart contract

The critical node group carries these labels by default:

```
juliarun/node-class = critical
juliarun/schedule   = no
juliarun/cpu        = prevent_juliarun_jobs
```

and the taint `CriticalAddonsOnly=true:NoSchedule`.

Two things select on `juliarun/node-class`: the platform Helm chart's `nodeSelector` values, and the `addon_node_selector` that pins the CoreDNS and CSI controllers here. Addon tolerations are derived from `critical_node_taints` automatically.

Override `critical_node_labels` and `critical_node_taints` if you need different names, but set matching values in the chart or platform pods will not schedule.

## Node groups and autoscaling

The node group this module creates is deliberately small — it exists to run platform components and cluster addons, and it is tainted so general workloads stay off it.

JuliaHub jobs run on nodes provisioned by an autoscaler, which this module does not install. With Karpenter, leave `enable_karpenter_discovery_tag` enabled and pass the Karpenter node role through `additional_node_role_arns` so its nodes can register:

```hcl
additional_node_role_arns = ["arn:aws:iam::111122223333:role/KarpenterNodeRole"]
```

## Addon versions

Leaving a `*_version` variable empty selects the latest version compatible with `kubernetes_version`. Pin a version when you need reproducibility.

Note that AWS does not publish every addon version for every Kubernetes version. When upgrading the control plane, check that any pinned addon versions exist for the target version first.

## IRSA

Each addon role trusts only its own service account, scoped on both the `sub` and `aud` claims. Build platform roles the same way using the module outputs:

```hcl
condition {
  test     = "StringEquals"
  variable = "${module.eks.oidc_provider}:sub"
  values   = ["system:serviceaccount:juliahub:juliahub"]
}

condition {
  test     = "StringEquals"
  variable = "${module.eks.oidc_provider}:aud"
  values   = ["sts.amazonaws.com"]
}
```

## Bootstrap types

`bootstrap_type` must match the AMI family in `node_ami_id`:

| Value | AMI family |
|-------|-----------|
| `BOTTLEROCKET` | Bottlerocket (default) |
| `AL2023` | Amazon Linux 2023 |
| `AMAZONLINUX2` | Amazon Linux 2 |

Leaving `node_ami_id` empty resolves the latest Bottlerocket AMI, so it pairs only with `BOTTLEROCKET`.

## Inputs

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults.

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | Name of the cluster |
| `cluster_arn` | ARN of the cluster |
| `cluster_endpoint` | Kubernetes API server endpoint |
| `cluster_version` | Kubernetes version on the control plane |
| `cluster_certificate_authority_data` | Base64 CA data, for a kubeconfig |
| `cluster_security_group_id` | Cluster security group |
| `oidc_provider` | OIDC issuer host and path, for IRSA conditions |
| `oidc_provider_arn` | OIDC provider ARN, for IRSA trust policies |
| `node_role_arn` | Node instance role ARN |
| `node_role_name` | Node instance role name |
| `node_group_name` | Critical node group name |
| `critical_node_labels` | Labels on the critical node group |
