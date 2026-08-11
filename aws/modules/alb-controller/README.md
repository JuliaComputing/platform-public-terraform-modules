# AWS Load Balancer Controller IAM Module

Creates the IRSA role the [AWS Load Balancer Controller](https://github.com/kubernetes-sigs/aws-load-balancer-controller) assumes.

## This does not install the controller

**AWS publishes no EKS managed add-on for the load balancer controller.** The add-on catalog covers the CNI, CoreDNS, kube-proxy, the CSI drivers, and a set of AWS and partner agents, but the load balancer controller is not among them. It is installed by Helm from the upstream chart.

This module creates only the AWS-side piece — the IAM role — so the chart's service account has something to annotate:

```bash
helm repo add eks https://aws.github.io/eks-charts

helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system \
  --set clusterName=<cluster_name> \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set-string serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<iam_role_arn>
```

The controller also needs the subnet tags the `vpc` module already applies: `kubernetes.io/role/elb` on public subnets and `kubernetes.io/role/internal-elb` on private ones.

## Usage

```hcl
module "alb_controller" {
  source = "./modules/alb-controller"

  cluster_name = module.eks.cluster_name

  tags = {
    Environment = "production"
  }
}
```

Then point the platform's ingress at it:

```yaml
websrvr:
  external:
    enabled: false
  ingress:
    enabled: true
    className: alb
    annotations:
      alb.ingress.kubernetes.io/scheme: internet-facing
      alb.ingress.kubernetes.io/target-type: ip
      alb.ingress.kubernetes.io/certificate-arn: <acm_certificate_arn>
```

Set `websrvr.external.enabled` to `false` when using an Ingress; otherwise the chart also creates a `LoadBalancer` Service and you get two load balancers.

## The IAM policy

`iam_policy.json` is vendored from the upstream project rather than hand-written, so the permission set stays aligned with a known release:

```
https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v3.5.0/docs/install/iam_policy.json
```

To refresh it, download the file for the controller version you run and commit the result. Check the diff — the policy grows as the controller gains features, and a controller newer than the policy fails at runtime with opaque `AccessDenied` errors from the ELB API.

## Inputs

| Variable | Default | Description |
|----------|---------|-------------|
| `cluster_name` | — | EKS cluster name |
| `namespace` | `kube-system` | Namespace the controller runs in |
| `service_account_name` | `aws-load-balancer-controller` | Service account name |
| `role_name` | derived | IAM role name |
| `tags` | `{}` | Tags for the role |

## Outputs

| Output | Description |
|--------|-------------|
| `iam_role_arn` | Role ARN for the service account annotation |
| `iam_role_name` | Role name |
| `service_account_name` | Service account the role trusts |
| `namespace` | Namespace the role trusts it in |
