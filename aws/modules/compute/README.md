# Compute Module

Creates the AWS resources the JuliaHub Platform needs in order to run jobs: the datasets S3 bucket, CloudWatch log groups with S3 archives, and the IAM roles that tie them together.

## Features

- **Datasets bucket** — versioned, encrypted, TLS-only, with CORS for direct browser uploads and lifecycle rules for old versions and abandoned multipart uploads
- **IRSA role** for the platform service accounts, trust-scoped to a namespace and service account list
- **Assumable roles** for jobs, datasets, and job outputs, each with a least-privilege policy
- **Log groups** for audit and job logs, with S3 archive buckets that CloudWatch Logs export tasks can write to

## Usage

```hcl
module "compute" {
  source = "./modules/compute"

  name         = "juliahub.example.com"
  cluster_name = module.eks.cluster_name

  service_account_namespace = "juliahub"

  tags = {
    Environment = "production"
  }
}
```

Wire the outputs into the platform chart:

| Output | Helm value |
|--------|-----------|
| `service_account_role_arn` | `serviceAccount.annotations["eks.amazonaws.com/role-arn"]` |
| `datasets_bucket_name` | `compute.storage.aws.bucketName` |
| `datasets_role_arn` | `compute.storage.aws.storageRoleArn` |

## The roles

| Role | Assumed by | Grants |
|------|-----------|--------|
| `juliahub-compute.<name>` | Platform service accounts, via the cluster OIDC provider | Assume the three roles below; read the image registry; manage log groups; mount EFS. Also carries the datasets and logging policies directly, since the platform performs server-side S3 operations under its own identity. |
| `datasets.<name>` | The platform role | Read and write the platform prefixes of the datasets bucket |
| `jobs.<name>` | The platform role | Write job and audit log streams; manage job secrets in Secrets Manager |
| `job-outputs.<name>` | The platform role | Multipart upload into the results prefix. The job runner assumes this and attaches a session policy narrowing it to a single job's prefix. |

To let a principal outside the cluster assume the jobs and datasets roles — an EC2 instance profile, for example — pass its ARN in `additional_trusted_role_arns`.

## Bucket layout

The datasets bucket is partitioned by prefix, and the IAM policies are scoped to exactly these:

| Prefix | Variable | Contents |
|--------|----------|----------|
| `datasets/` | `datasets_s3_prefix` | User datasets |
| `results/` | `results_s3_prefix` | Job result files |
| `applications/` | `applications_s3_prefix` | Application data |
| `inputs/` | `inputs_s3_prefix` | Job inputs |
| `lfs/` | `lfs_s3_prefix` | Git LFS objects |

## CORS and direct uploads

The platform UI uploads datasets straight from the browser to S3, so the bucket must allow cross-origin `PUT` from the platform hostname. `allowed_origins` defaults to `[name]`, which is correct when `name` is the platform hostname. Set it explicitly otherwise:

```hcl
allowed_origins = ["juliahub.example.com", "www.juliahub.example.com"]
```

Uploads fail in the browser if this does not match the address users load the platform from.

## Object scanning

This module does not scan uploaded objects for malware. If you need that, run a scanner of your own and wire it up with the two hooks provided.

Send object-created events to your scanner's queue:

```hcl
datasets_bucket_notifications = {
  "scanner" = {
    queue_arn = "arn:aws:sqs:us-east-1:111122223333:object-scan"
  }
}
```

The queue's own access policy must allow `s3.amazonaws.com` to send messages to it.

Then grant the scanner access to the bucket:

```hcl
additional_datasets_bucket_policy_statements = [
  data.aws_iam_policy_document.scanner_access.json,
]
```

Statements passed this way are merged into the bucket policy alongside the module's own TLS-only deny.

## Using an existing bucket

Set `create_datasets_bucket = false` and pass `datasets_bucket_name`. The IAM policies are then scoped to that bucket, but its configuration — versioning, encryption, CORS, lifecycle — is yours to manage.

## Inputs

See [`variables.tf`](variables.tf) for the full list with descriptions and defaults.

## Outputs

| Output | Description |
|--------|-------------|
| `service_account_role_arn` | IRSA role ARN for the platform service accounts |
| `service_account_role_name` | IRSA role name |
| `jobs_role_arn` | Jobs role ARN |
| `datasets_role_arn` | Datasets role ARN |
| `job_outputs_role_arn` | Job outputs role ARN |
| `datasets_bucket_name` | Datasets bucket name |
| `datasets_bucket_arn` | Datasets bucket ARN |
| `audit_log_group_name` | Audit log group name |
| `job_log_group_name` | Job log group name |
| `audit_log_archive_bucket_name` | Audit log archive bucket name |
| `job_log_archive_bucket_name` | Job log archive bucket name |
