# JuliaHub Platform on AWS

Terraform for the AWS infrastructure a self-managed JuliaHub Platform install needs: a VPC, an EKS cluster, a database, shared filesystems, and the IAM the platform and its cluster controllers assume — all configured to match what the platform Helm chart expects.

This is a self-contained root module. Apply it, point `kubectl` at the resulting cluster, install the Karpenter and load balancer controller charts, then install the platform chart.

## What this creates

| Component | Details |
|-----------|---------|
| VPC | Public and private subnets across two availability zones, internet gateway, one NAT gateway per public subnet |
| VPC endpoints | ECR (interface) and S3 (gateway) by default; RDS and Bedrock optional |
| EKS cluster | Control plane with API-based access entries, OIDC provider for IRSA |
| Node group | A small "critical" node group for platform components and addons |
| Addons | `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`, each with its own IRSA role |
| PostgreSQL | An encrypted RDS instance, reachable only from the cluster |
| Shared filesystems | Two EFS filesystems with access points, for the config directory and per-user job storage |
| Karpenter IAM | Controller and node roles, instance profile, and the interruption queue for graceful spot handling |
| Load balancer IAM | IRSA role for the AWS Load Balancer Controller |
| Compute resources | Datasets S3 bucket, audit and job log groups with S3 archives, and the IAM roles the platform assumes to run jobs |

Each of these can be turned off — `create_rds`, `create_efs_config_directory`, `create_efs_userdata_directory`, `create_compute`, `create_karpenter_iam`, `create_alb_controller_iam` — if you manage them yourself.

### Controllers are IAM-only

AWS publishes **no EKS managed add-on** for either Karpenter or the AWS Load Balancer Controller. The managed add-on catalog covers the CNI, CoreDNS, kube-proxy, the CSI drivers, and a set of AWS and partner agents; both of these are installed by Helm from their upstream charts instead.

So this module creates their AWS-side resources — IAM roles, Karpenter's instance profile and interruption queue — and leaves the in-cluster install to Helm.

**Both charts must be given tolerations for the critical node group's `CriticalAddonsOnly` taint**, or their pods never schedule. Pass `$(terraform output -raw critical_node_tolerations_helm_set)` to each `helm install`. Missing this on Karpenter deadlocks the cluster: the controller cannot schedule, so it never provisions the untainted nodes that would host it. The two module READMEs carry the matching `helm install` invocations. Everything the charts need from AWS, including the subnet and security group discovery tags Karpenter selects on, is already wired up here.

## What this does not create

These are outside the scope of this module and must be provisioned separately:

- **The Karpenter and load balancer controller installs themselves** — their IAM is created here, but the charts are yours to deploy. See above.
- **Route 53 records pointing at the ALB** — the load balancer only exists after the platform install, so its hostname is CNAME'd afterwards.
- **A TLS certificate**, unless you use the optional [modules/acm-certificate](modules/acm-certificate/). See below.
- **Object scanning** — the datasets bucket has hooks for wiring up a scanner of your own; see [modules/compute](modules/compute/).

See the [AWS installation guide](https://help.juliahub.com/juliahub/stable/installation/) for how these map to Helm values.

## Mapping outputs to Helm values

After `terraform apply`, these outputs populate a `myvalues.yaml`:

| Output | Helm value |
|--------|-----------|
| `postgres_host` | `postgres.external.host` |
| `postgres_port` | `postgres.external.port` |
| `postgres_username` | `postgres.external.username` |
| `postgres_password` | `postgres.external.password` |
| `config_directory_efs_filesystem_id` | `configDirectory.efs.filesystemId` |
| `config_directory_efs_access_point_id` | `configDirectory.efs.accessPointId` |
| `userdata_directory_efs_filesystem_id` | `compute.userdataDirectory.efs.filesystemId` |
| `userdata_directory_efs_access_point_id` | `compute.userdataDirectory.efs.accessPointId` |
| `compute_service_account_role_arn` | `serviceAccount.annotations["eks.amazonaws.com/role-arn"]` |
| `datasets_bucket_name` | `compute.storage.aws.bucketName` |
| `datasets_role_arn` | `compute.storage.aws.storageRoleArn` |
| `jobs_role_arn` | `compute.cloudhost.aws.roleArn` |
| `cloudhost_max_session_duration` | `compute.cloudhost.aws.maxSessionDuration` |
| `region` (your `region` input) | `compute.cloudhost.aws.region` |

Controller outputs go to their own Helm charts rather than the platform chart:

| Output | Used by |
|--------|---------|
| `karpenter_controller_role_arn` | Karpenter chart, `serviceAccount.annotations` |
| `karpenter_interruption_queue_name` | Karpenter chart, `settings.interruptionQueue` |
| `karpenter_node_role_name` | Your `EC2NodeClass` `role` field |
| `alb_controller_role_arn` | Load balancer controller chart, `serviceAccount.annotations` |
| `alb_ingress_certificate_arn` | Platform chart, `websrvr.ingress.annotations["alb.ingress.kubernetes.io/certificate-arn"]` |

Alongside these, set the type discriminators the chart needs:

```yaml
postgres:
  type: external
  external:
    requiresSSL: true

configDirectory:
  type: efs
  efs:
    useIAM: true   # the filesystem policy restricts mounts to the node role

compute:
  enabled: true
  userdataDirectory:
    type: efs
```

`compute.enabled` is gated by your Replicated license — check entitlement with JuliaHub support before setting it.

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

## TLS

TLS terminates at the ALB, not in the cluster. The platform serves plain HTTP behind it, so the chart needs `offloadTLS: true` and no `tlsFullchainPem` / `tlsPrivkeyPem`.

Give the root module a certificate ARN and it comes back out as `alb_ingress_certificate_arn`, which goes on the chart's ingress annotation. The load balancer controller attaches it to the listener when it creates the ALB:

```hcl
certificate_arn = "arn:aws:acm:us-east-1:111122223333:certificate/abc-123"
```

Where that ARN comes from is up to you — an existing ACM certificate, one imported from an internal CA, or anything your organisation's issuance process produces. When the parent zone is in Route 53, [modules/acm-certificate](modules/acm-certificate/) will create and validate one:

```hcl
module "certificate" {
  source = "./modules/acm-certificate"

  domain_name       = "juliahub.example.com"
  route53_zone_name = "example.com"

  providers = {
    aws         = aws
    aws.route53 = aws
  }
}

module "juliahub" {
  source          = "./"
  certificate_arn = module.certificate.certificate_arn
}
```

Leaving `certificate_arn` empty means the ALB has no certificate and serves HTTP only, which is fine for a scratch install and not much else.

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

Nodes need an access entry too. The node group's role and, when `create_karpenter_iam` is enabled, the Karpenter node role are both registered automatically. Use `additional_node_role_arns` only for node roles created outside this module:

```hcl
additional_node_role_arns = ["arn:aws:iam::111122223333:role/OtherNodeRole"]
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
| [modules/rds](modules/rds/) | PostgreSQL RDS instance, parameter group, optional alarms |
| [modules/efs](modules/efs/) | EFS filesystem, access point, and mount targets for one shared directory |
| [modules/karpenter](modules/karpenter/) | Karpenter IAM roles, instance profile, interruption queue |
| [modules/alb-controller](modules/alb-controller/) | IRSA role for the AWS Load Balancer Controller |
| [modules/acm-certificate](modules/acm-certificate/) | ACM certificate for the platform hostname, DNS-validated in Route 53 |
| [modules/compute](modules/compute/) | Datasets bucket, log groups and archives, compute IAM roles |

Each can be consumed independently — for instance, `modules/compute` against a cluster you already run, or `modules/eks` with a database you manage elsewhere.

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
