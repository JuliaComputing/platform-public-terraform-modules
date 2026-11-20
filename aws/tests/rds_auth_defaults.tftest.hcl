# Applies the root module against mocked providers, so it runs without
# credentials: `terraform test` from aws/. Covers which database authentication
# the module sets up by default and with the opt-out. Everything except the
# rds and rds_iam modules is stubbed out with override_module.

mock_provider "aws" {
  # Mocked strings are random, and IAM resources validate their policy JSON.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_region" {
    defaults = { name = "us-east-1", region = "us-east-1" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_resource "aws_db_instance" {
    defaults = {
      resource_id = "db-ABCDEFGHIJKL"
      master_user_secret = [{
        secret_arn    = "arn:aws:secretsmanager:us-east-1:111122223333:secret:rds!db-1234"
        kms_key_id    = "arn:aws:kms:us-east-1:111122223333:key/abcd"
        secret_status = "active"
      }]
    }
  }
  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::111122223333:role/mocked"
    }
  }
}

mock_provider "random" {}
mock_provider "tls" {}

override_module {
  target = module.vpc
  outputs = {
    vpc_id             = "vpc-0123456789abcdef0"
    private_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    public_subnet_ids  = ["subnet-0123456789abcdef2", "subnet-0123456789abcdef3"]
  }
}

override_module {
  target = module.eks
  outputs = {
    cluster_name              = "juliahub"
    cluster_security_group_id = "sg-0123456789abcdef0"
    node_role_arn             = "arn:aws:iam::111122223333:role/juliahub-node"
    oidc_provider             = "oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
    oidc_provider_arn         = "arn:aws:iam::111122223333:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
  }
}

override_module {
  target = module.compute
  outputs = {
    service_account_role_name = "juliahub-platform"
    service_account_role_arn  = "arn:aws:iam::111122223333:role/juliahub-platform"
  }
}

override_module {
  target = module.karpenter
  outputs = {
    node_role_arn = "arn:aws:iam::111122223333:role/juliahub-karpenter-node"
  }
}

override_module {
  target = module.alb_controller
}

override_module {
  target = module.efs_config
}

override_module {
  target = module.efs_userdata
}

override_module {
  target = module.windows_workstation
}

run "defaults_to_iam_auth_with_managed_master_password" {
  assert {
    condition     = output.postgres_auth == "iam"
    error_message = "the platform should connect with IAM authentication by default"
  }

  assert {
    condition     = output.postgres_username == "juliahub_iam" && output.postgres_password == null
    error_message = "by default postgres_username should be the IAM database role and postgres_password null"
  }

  assert {
    condition     = output.postgres_iam_bootstrap_role_arn != null
    error_message = "the bootstrap Job's IRSA role should be created by default"
  }

  assert {
    condition     = output.postgres_master_user_secret_arn != null && output.postgres_iam_provisioner_role_arn != null
    error_message = "by default RDS should manage the master password, with an IRSA role for the create-database-user hook to read it"
  }
}

run "opt_out_keeps_password_auth" {
  variables {
    rds_iam_database_authentication_enabled = false
    rds_manage_master_user_password         = false
  }

  assert {
    condition     = output.postgres_auth == "password"
    error_message = "with both set false the platform should use password authentication"
  }

  assert {
    condition     = output.postgres_password != null && output.postgres_username == output.postgres_master_username
    error_message = "with both set false Terraform should generate the master password and the platform should connect as the master user"
  }

  assert {
    condition     = output.postgres_iam_bootstrap_role_arn == null && output.postgres_iam_admin_username == null
    error_message = "no IAM authentication roles should be created with password authentication"
  }
}
