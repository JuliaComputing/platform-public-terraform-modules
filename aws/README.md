# JuliaHub Platform on AWS

Terraform for the AWS infrastructure a self-managed JuliaHub Platform install needs: a VPC and an EKS cluster configured to match what the platform Helm chart expects.

This is a self-contained root module. Apply it, point `kubectl` at the resulting cluster, then install the platform chart.

## What this creates

| Component | Details |
|-----------|---------|
| VPC | Public and private subnets across two availability zones, internet gateway, one NAT gateway per public subnet |
| VPC endpoints | ECR (interface) and S3 (gateway) by default; RDS and Bedrock optional |
| EKS cluster | Control plane with API-based access entries, OIDC provider for IRSA |
| Node group | A small "critical" node group for platform components and addons |
| Addons | `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`, each with its own IRSA role |

## What this does not create

These are outside the scope of this module and must be provisioned separately:

- **EFS filesystem and access points** — the platform stores its config and userdata directories on EFS. The CSI driver is installed here, but the filesystem is not created.
- **PostgreSQL** — use RDS or another external PostgreSQL.
- **S3 bucket and IAM roles for compute** — for job data and job outputs.
- **An autoscaler** — the node group here runs platform components only. Job nodes need Karpenter or Cluster Autoscaler.
- **ALB, ACM certificate, and Route 53 records** — for ingress and TLS.
- **AWS Load Balancer Controller.**

See the [AWS installation guide](https://help.juliahub.com/juliahub/stable/installation/) for how these map to Helm values.

## Prerequisites

- Terraform >= 1.5.0
- AWS credentials with permission to create VPC, EKS, and IAM resources
- The principal running `terraform apply` becomes a cluster admin automatically

## Usage

```bash
cd aws/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

Then configure `kubectl`:

```bash
aws eks update-kubeconfig --region us-east-1 --name juliahub
```

## Node labels are a chart contract

The critical node group carries these labels by default:

```
juliarun/node-class = critical
juliarun/schedule   = no
juliarun/cpu        = prevent_juliarun_jobs
```

and this taint:

```
CriticalAddonsOnly=true:NoSchedule
```

The platform Helm chart's `nodeSelector` values, and the addon configuration in this module, both select on `juliarun/node-class`. They are exposed as `critical_node_labels` and `critical_node_taints` so you can change them, but if you do you must set matching values in the chart or platform pods will not schedule.

## Granting cluster access

The cluster uses EKS access entries (`authentication_mode = "API"`), not `aws-auth`. Grant access with `access_entries`:

```hcl
access_entries = [
  {
    principal_arn = "arn:aws:iam::111122223333:role/PlatformAdmin"
    username      = "PlatformAdmin"
  },
]
```

If you run Karpenter, pass its node role through `additional_node_role_arns` so nodes it launches can join:

```hcl
additional_node_role_arns = ["arn:aws:iam::111122223333:role/KarpenterNodeRole"]
```

## IRSA

The module creates an IAM OIDC provider for the cluster and outputs `oidc_provider` and `oidc_provider_arn`. Use these to build trust policies for the platform's own service account roles:

```hcl
data "aws_iam_policy_document" "platform_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

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
  }
}
```

## Private API server endpoints

`endpoint_public_access_cidrs` defaults to `0.0.0.0/0`. Narrow it to your own egress ranges, or set `endpoint_public_access = false` for a fully private cluster. A private cluster requires network access into the VPC (VPN, Direct Connect, or a bastion) for both `terraform apply` and `kubectl`.

## Additional PrivateLink endpoints

For PrivateLink services specific to your environment, use `additional_interface_vpc_endpoints`:

```hcl
additional_interface_vpc_endpoints = {
  "vendor-api" = {
    service_name        = "com.amazonaws.vpce.us-east-1.vpce-svc-0123456789abcdef0"
    private_dns_enabled = true
  }
}
```

## Modules

| Module | Description |
|--------|-------------|
| [modules/vpc](modules/vpc/) | VPC, subnets, routing, NAT gateways, VPC endpoints |
| [modules/eks](modules/eks/) | EKS cluster, node group, addons, IAM roles, access entries |

Both can be consumed independently if you already have a VPC.

## Inputs

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults. The ones most likely to need changing:

| Variable | Default | Notes |
|----------|---------|-------|
| `cluster_name` | `juliahub` | Names the cluster, VPC, and subnets |
| `region` | `us-east-1` | |
| `availability_zones` | `["us-east-1a", "us-east-1c"]` | Must match `region` |
| `kubernetes_version` | `1.33` | |
| `vpc_cidr` | `192.168.0.0/16` | Must not overlap `service_ipv4_cidr` |
| `node_instance_type` | `t3.large` | |
| `endpoint_public_access_cidrs` | `["0.0.0.0/0"]` | Narrow this in production |
