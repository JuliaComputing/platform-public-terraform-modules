# Karpenter IAM Module

Creates the IAM roles, instance profile, and interruption queue [Karpenter](https://karpenter.sh) needs to provision nodes.

## This does not install Karpenter

**AWS publishes no EKS managed add-on for Karpenter.** It is installed by Helm from the upstream OCI chart. This module creates only the AWS-side resources that chart expects:

```bash
helm install karpenter oci://public.ecr.aws/karpenter/karpenter \
  --namespace kube-system \
  --set settings.clusterName=<cluster_name> \
  --set settings.interruptionQueue=<interruption_queue_name> \
  --set-string serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<controller_role_arn>
```

> **Tolerations are required.** The only node group the `eks` module creates is
> tainted `CriticalAddonsOnly=true:NoSchedule`, so this chart's pods stay
> `Pending` unless they tolerate it. The root module exposes the right values as
> `critical_node_tolerations_helm_set`:
>
> ```bash
> helm install ... $(terraform output -raw critical_node_tolerations_helm_set)
> ```
>
> For Karpenter this is self-inflicted deadlock if missed: the controller cannot
> schedule, so it never provisions the untainted nodes that would host it.

You then create an `EC2NodeClass` referencing the node role, and one or more `NodePool` resources describing the capacity you want:

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  role: <node_role_name>
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: <cluster_name>
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: <cluster_name>
```

The discovery tags those selectors match are applied by the `vpc` module (on private subnets) and the `eks` module (on the cluster security group, via `enable_karpenter_discovery_tag`).

## Why the platform needs an autoscaler

The `eks` module's node group is small and tainted — it runs platform components and cluster addons only. JuliaHub jobs run on nodes provisioned on demand, so without an autoscaler, job pods stay `Pending` indefinitely.

## Usage

```hcl
module "karpenter" {
  source = "./modules/karpenter"

  cluster_name = module.eks.cluster_name

  tags = {
    Environment = "production"
  }
}
```

## Wiring the node role

Nodes Karpenter launches must be able to **join the cluster** and **mount EFS**. Both key off the node role, not any pod identity, so it has to be granted in two other places:

```hcl
module "eks" {
  additional_node_role_arns = [module.karpenter.node_role_arn]
}

module "efs_config" {
  restrict_mount_to_role_arns = [module.eks.node_role_arn, module.karpenter.node_role_arn]
}
```

The root module does both automatically. Consuming this module standalone means wiring them yourself — and the failure is easy to misread, since the cluster comes up fine and only job pods fail, either stuck `NotReady` or unable to mount their userdata volume.

## Interruption handling

`create_interruption_queue` provisions an SQS queue and the EventBridge rules that feed it: spot interruption warnings, rebalance recommendations, instance state changes, and AWS health events.

Without it, Karpenter finds out about an interruption when the node vanishes, so pods are killed rather than drained. With it, there is a window to cordon and drain first. Recommended whenever spot capacity is in use, and harmless otherwise.

## Controller permissions

The controller policy is scoped more tightly than the permissive examples in circulation:

- Instance termination and launch template deletion are conditioned on the `kubernetes.io/cluster/<cluster_name>: owned` tag, so the controller can only tear down what it created for this cluster.
- `iam:PassRole` is restricted to the node role this module creates, rather than `*`. Unscoped `PassRole` would let anything holding this role hand any role to EC2.
- Instance profile management is scoped to the IAM path Karpenter generates, `/karpenter/<region>/<cluster>/<uuid>/`, plus profiles named for the cluster. Scoping only to the latter denies every `CreateInstanceProfile` call, since the profiles Karpenter creates are pathed rather than at the root.
- Queue access is granted only when the interruption queue exists.

## Inputs

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults.

## Outputs

| Output | Description |
|--------|-------------|
| `controller_role_arn` | Controller IRSA role ARN, for the chart's service account annotation |
| `controller_role_name` | Controller role name |
| `node_role_arn` | Node role ARN, for cluster access entries and EFS mount policies |
| `node_role_name` | Node role name, for the `EC2NodeClass` `role` field |
| `node_instance_profile_name` | Node instance profile name. Karpenter does not use this: it creates its own profile per `EC2NodeClass`, under the IAM path `/karpenter/<region>/<cluster>/<uuid>/`. |
| `interruption_queue_name` | Queue name, for the chart's `settings.interruptionQueue` |
| `interruption_queue_arn` | Queue ARN |
