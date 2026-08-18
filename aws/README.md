# JuliaHub Platform on AWS

Terraform for the AWS infrastructure a self-managed JuliaHub Platform install needs: a VPC, an EKS cluster, a database, shared filesystems, and the IAM the platform and its cluster controllers assume — all configured to match what the platform Helm chart expects.

This is a self-contained root module. Apply it, point `kubectl` at the resulting cluster, install the Karpenter and load balancer controller charts, then install the platform chart.

The [AWS installation guide](https://help.juliahub.com/juliahub/stable/installation/aws_helm/) walks through that end to end — prerequisites, the Helm values these outputs feed, TLS, DNS and verification. This README covers the Terraform side; start with the guide if you are installing the platform for the first time.

## What this creates

| Component | Details |
|-----------|---------|
| VPC | Public and private subnets across two availability zones, internet gateway, one NAT gateway per public subnet. Optional — pass `vpc_id` with your own subnets instead |
| VPC endpoints | ECR (interface) and S3 (gateway) by default; RDS and Bedrock optional |
| EKS cluster | Control plane with API-based access entries, OIDC provider for IRSA |
| Node group | A small "critical" node group for platform components and addons |
| Addons | `vpc-cni`, `coredns`, `kube-proxy`, `aws-ebs-csi-driver`, `aws-efs-csi-driver`, each with its own IRSA role |
| PostgreSQL | An encrypted RDS instance, reachable only from the cluster |
| Shared filesystems | Two EFS filesystems with access points, for the config directory and per-user job storage |
| Karpenter IAM | Controller and node roles, instance profile, and the interruption queue for graceful spot handling |
| Load balancer IAM | IRSA role for the AWS Load Balancer Controller |
| Compute resources | Datasets S3 bucket, audit and job log groups with S3 archives, and the IAM roles the platform assumes to run jobs |

Every part of this is opt-out. Nothing here is required in order to use the
rest, so the modules can take on as much or as little of the infrastructure as
you want:

| Turn off | With | Instead |
|----------|------|---------|
| VPC and subnets | `vpc_id`, `private_subnet_ids`, `public_subnet_ids` | Your existing VPC — see [Deploying into an existing VPC](#deploying-into-an-existing-vpc) |
| PostgreSQL | `create_rds = false` | Your own RDS instance or Aurora cluster |
| Config directory filesystem | `create_efs_config_directory = false` | An EFS filesystem you manage |
| Userdata filesystem | `create_efs_userdata_directory = false` | An EFS filesystem you manage |
| Compute resources | `create_compute = false` | Your own bucket, log groups and job IAM roles |
| Karpenter IAM | `create_karpenter_iam = false` | Your own autoscaler, or IAM you manage |
| Load balancer IAM | `create_alb_controller_iam = false` | IAM you manage |

The submodules are also usable directly, without the root module, if you want
only one or two pieces — see [Using the modules individually](#using-the-modules-individually).

The EKS cluster itself is the one thing the root module always creates. To bring
your own cluster and use the modules only for what the platform adds around it,
call the submodules individually rather than the root module.

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

See the [AWS installation guide](https://help.juliahub.com/juliahub/stable/installation/aws_helm/) for how these map to Helm values.

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

## Naming

`platform_hostname` is the hostname users load the platform from. It is the
default CORS origin for direct dataset uploads, so it has to be the real
hostname — a browser upload from a different origin is refused.

It also seeds the names of the generated IAM roles, buckets and log groups, with
dots flattened to hyphens for S3. Those have hard limits: 63 characters for a
bucket name, 64 for an IAM role name, and the derived suffixes
(`-datasets`, `-job-logs-archive`, `job-outputs.`) eat into the budget. A long
hostname overflows them and fails the apply partway through, after the VPC and
cluster already exist.

Set `resource_name_prefix` when that is a risk. It replaces the derived prefix
for resource names and leaves the CORS origin alone:

```hcl
platform_hostname    = "juliahub.long.subdomain.example.com"
resource_name_prefix = "juliahub"
```

gives `juliahub-datasets`, `jobs.juliahub`, and a CORS origin of
`juliahub.long.subdomain.example.com`.

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

## Deploying into an existing VPC

Most enterprise accounts already have a VPC with the subnets, routing and egress
the platform needs. Pass it in and the vpc submodule is skipped:

```hcl
module "juliahub" {
  source = "github.com/JuliaComputing/platform-public-terraform-modules//aws"

  cluster_name = "juliahub"
  region       = "us-east-1"

  vpc_id             = "vpc-0123456789abcdef0"
  private_subnet_ids = ["subnet-0aaa...", "subnet-0bbb..."]
  public_subnet_ids  = ["subnet-0ccc...", "subnet-0ddd..."]
}
```

The VPC-shaping inputs (`vpc_cidr`, `public_subnet_cidrs`,
`private_subnet_cidrs`, `availability_zones`, the `enable_*_vpc_endpoint` flags)
are then ignored — routing, NAT and endpoints are yours to manage. Everything
else is unchanged: EKS, EFS, RDS, the datasets bucket and the IAM roles are
still created, in the subnets you named.

Private subnets need outbound internet access, or VPC endpoints for ECR, S3 and
CloudWatch Logs, or nodes cannot pull images.

### Your subnets must carry the discovery tags

This is the part that catches people out. The AWS Load Balancer Controller and
Karpenter do not take a list of subnets — they **discover** subnets by tag:

| Tag | On | Consumer | If missing |
|-----|----|----------|------------|
| `kubernetes.io/role/elb` | public subnets | AWS Load Balancer Controller | The platform Ingress never gets an ALB |
| `kubernetes.io/role/internal-elb` | private subnets | AWS Load Balancer Controller | No internal load balancer is placed |
| `karpenter.sh/discovery = <cluster_name>` | private subnets | Karpenter | No job nodes are ever provisioned |

None of these produce an error at apply time. The cluster comes up, the pods run
and the platform reports healthy — and then no load balancer appears, or jobs
sit pending forever. When the modules create the VPC they apply these tags for
you, which is why the failure only shows up on the bring-your-own-VPC path.

There are two ways to handle it:

**Let the modules tag your subnets** — set `tag_existing_subnets = true`. This is
off by default because it means Terraform manages tags on resources it did not
create, and `terraform destroy` will remove them again. If your subnets are
shared with other workloads, or another team owns them, prefer the other option.

**Tag them yourself** and leave `tag_existing_subnets = false`. The modules then
check the tags at plan time and fail with a message naming the missing tag, so a
mistake surfaces before anything is created. Set
`validate_existing_subnet_tags = false` to skip the check.

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

### Using the modules individually

The root module is a convenience: it wires the submodules together with sensible defaults. Every submodule is also usable on its own, so you can adopt the parts you want and keep whatever you already run.

That matters most when you already have an EKS cluster. You can skip `modules/eks` entirely and still use the modules for the pieces the platform needs around it:

```hcl
# Existing cluster and network; create only what the platform adds.
data "aws_eks_cluster" "existing" {
  name = "my-cluster"
}

module "config_efs" {
  source = "github.com/JuliaComputing/platform-public-terraform-modules//aws/modules/efs?depth=1"

  name       = "juliahub"
  purpose    = "config"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-aaa", "subnet-bbb"] # one per availability zone

  allow_from_security_group_ids = [
    data.aws_eks_cluster.existing.vpc_config[0].cluster_security_group_id,
  ]
}

module "compute" {
  source = "github.com/JuliaComputing/platform-public-terraform-modules//aws/modules/compute?depth=1"

  name         = "juliahub.example.com"
  cluster_name = data.aws_eks_cluster.existing.name

  # The cluster already exists, so the module can look up its OIDC issuer
  # rather than being told. Pass oidc_provider and set lookup_cluster = false
  # only when the cluster is created in the same apply.
}
```

Repeat `modules/efs` with `purpose = "userdata"` for per-job storage, and add `modules/rds`, `modules/acm-certificate`, `modules/karpenter` or `modules/alb-controller` as needed. Each module's README lists its inputs and outputs.

Two things to know when composing them yourself:

- **The root module wires up cross-cutting details you now own.** It grants the Karpenter node role access to the cluster and to the EFS filesystems, and passes the EKS cluster security group to RDS and EFS so only cluster workloads can reach them. Consuming submodules directly means doing that wiring in your own configuration; the `karpenter` and `efs` READMEs spell out which values go where.
- **`lookup_cluster` decides how the IRSA modules find the cluster.** Against an existing cluster leave it at its default and the module looks the cluster up by name. When the cluster is created in the same apply that lookup fails at plan time, so the root module passes `oidc_provider` through and sets `lookup_cluster = false`.

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
