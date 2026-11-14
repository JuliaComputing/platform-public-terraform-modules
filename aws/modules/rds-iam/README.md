# RDS IAM Authentication Module

Creates the IRSA roles the platform chart needs to connect to RDS with IAM database authentication (`postgres.external.auth: iam`). Use it with the [`rds`](../rds/) module's `iam_database_authentication_enabled` and, optionally, `manage_master_user_password`.

Each identity gets only what it needs:

| Identity | Service account | Permission |
|----------|-----------------|------------|
| Platform services | The existing platform role (`platform_role_name`) | `rds-db:connect` as `juliahub_iam`; denied the master user secret |
| Bootstrap Job | `juliahub-bootstrap` | `rds-db:connect` as `juliahub_admin_iam` |
| `create-database-user` hook | `juliahub-db-provisioner` | Read the master user secret (only with `manage_master_user_password`) |

The deny on the platform role is there because the [`compute`](../compute/) module's Secrets Manager policy covers every secret in the account, which would include the master user secret.

## Usage

```hcl
module "rds_iam" {
  source = "./modules/rds-iam"

  name           = module.rds.identifier
  cluster_name   = module.eks.cluster_name
  lookup_cluster = false
  oidc_provider  = module.eks.oidc_provider

  iam_connect_policy_json       = module.rds.iam_connect_policy_json
  iam_admin_connect_policy_json = module.rds.iam_admin_connect_policy_json

  attach_to_platform_role = true
  platform_role_name      = module.compute.service_account_role_name

  manage_master_user_password         = true
  master_user_secret_arn              = module.rds.master_user_secret_arn
  master_user_secret_read_policy_json = module.rds.master_user_secret_read_policy_json
}
```

## Outputs

| Output | Helm value |
|--------|-----------|
| `bootstrap_role_arn` | `postgres.external.iam.bootstrapServiceAccountAnnotations["eks.amazonaws.com/role-arn"]` |
| `provisioner_role_arn` | `postgres.external.iam.provisionerServiceAccountAnnotations["eks.amazonaws.com/role-arn"]` |
