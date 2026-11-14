# Applies the module against a mocked AWS provider, so it runs without
# credentials: `terraform test` from this directory. Covers the opt-in IAM
# database authentication and RDS-managed master password paths.

mock_provider "aws" {
  override_data {
    target = data.aws_caller_identity.current
    values = { account_id = "111122223333" }
  }
  override_data {
    target = data.aws_region.current
    values = { name = "us-east-1" }
  }
  override_data {
    target = data.aws_partition.current
    values = { partition = "aws" }
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
}

mock_provider "random" {}

variables {
  identifier          = "example-juliahub"
  deletion_protection = false
  skip_final_snapshot = true
  monitoring_interval = 0
}

run "defaults_keep_password_auth" {
  assert {
    condition     = length(random_password.master) == 1 && aws_db_instance._.password != null
    error_message = "by default the module generates the master password"
  }

  assert {
    condition     = output.connection_string != null
    error_message = "connection_string should be set when the module generates the password"
  }

  assert {
    condition     = !aws_db_instance._.iam_database_authentication_enabled
    error_message = "IAM database authentication should be off by default"
  }

  assert {
    condition     = output.iam_connect_policy_json == null && output.iam_admin_connect_policy_json == null
    error_message = "connect policies should be null without IAM authentication"
  }

  assert {
    condition     = output.master_user_secret_read_policy_json == null
    error_message = "secret read policy should be null without manage_master_user_password"
  }
}

run "iam_auth" {
  variables {
    iam_database_authentication_enabled = true
  }

  assert {
    condition     = aws_db_instance._.iam_database_authentication_enabled
    error_message = "IAM database authentication should be enabled on the instance"
  }

  assert {
    condition     = one(data.aws_iam_policy_document.iam_connect[0].statement).resources == toset(["arn:aws:rds-db:us-east-1:111122223333:dbuser:db-ABCDEFGHIJKL/juliahub_iam"])
    error_message = "platform connect policy must be scoped to the juliahub_iam database user"
  }

  assert {
    condition     = one(data.aws_iam_policy_document.iam_admin_connect[0].statement).resources == toset(["arn:aws:rds-db:us-east-1:111122223333:dbuser:db-ABCDEFGHIJKL/juliahub_admin_iam"])
    error_message = "admin connect policy must be scoped to the juliahub_admin_iam database user"
  }

  # IAM auth alone does not change how the master password is handled.
  assert {
    condition     = length(random_password.master) == 1 && output.connection_string != null
    error_message = "master password should still be generated without manage_master_user_password"
  }
}

run "managed_master_password" {
  variables {
    manage_master_user_password = true
  }

  assert {
    condition     = length(random_password.master) == 0 && aws_db_instance._.password == null
    error_message = "no password should be generated into state with manage_master_user_password"
  }

  assert {
    condition     = aws_db_instance._.manage_master_user_password
    error_message = "RDS should manage the master password"
  }

  assert {
    condition     = output.password == null && output.connection_string == null
    error_message = "password and connection_string must be null with manage_master_user_password"
  }

  assert {
    condition     = output.master_user_secret_arn == "arn:aws:secretsmanager:us-east-1:111122223333:secret:rds!db-1234"
    error_message = "master_user_secret_arn should come from the instance's managed secret"
  }

  assert {
    condition     = one(data.aws_iam_policy_document.master_user_secret_read[0].statement[*].sid) == "ReadRdsMasterUserSecret"
    error_message = "without a custom KMS key the read policy should only grant the secret, not kms:Decrypt"
  }
}

run "managed_master_password_custom_kms" {
  variables {
    manage_master_user_password   = true
    master_user_secret_kms_key_id = "arn:aws:kms:us-east-1:111122223333:key/abcd"
  }

  assert {
    condition     = toset(data.aws_iam_policy_document.master_user_secret_read[0].statement[*].sid) == toset(["ReadRdsMasterUserSecret", "DecryptRdsMasterUserSecret"])
    error_message = "with a custom KMS key the read policy must also grant kms:Decrypt on it"
  }
}
