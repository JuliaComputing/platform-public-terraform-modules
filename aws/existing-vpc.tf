# Support for deploying into a VPC the caller already owns.
#
# The subnets themselves are the easy part — they are just IDs passed through to
# the submodules. The part that silently breaks a bring-your-own-VPC deployment
# is tagging: the AWS Load Balancer Controller and Karpenter both *discover*
# subnets by tag rather than being told which to use. A cluster whose subnets
# lack those tags installs cleanly and reports healthy, then never provisions a
# load balancer for the Ingress and never launches a job node.
#
# So this file does two things: it can apply the tags (opt in, since they land
# on resources Terraform did not create), and otherwise it checks for them at
# plan time so the failure is loud and early rather than silent and late.

locals {
  # Only meaningful when the caller brought their own VPC.
  existing_subnet_ids = local.create_vpc ? [] : concat(var.private_subnet_ids, var.public_subnet_ids)

  tag_existing = !local.create_vpc && var.tag_existing_subnets
  # Checking and tagging are mutually exclusive: when we apply the tags
  # ourselves there is nothing to validate.
  validate_existing = !local.create_vpc && !var.tag_existing_subnets && var.validate_existing_subnet_tags
}

# vpc_id and the subnet lists have to arrive together; a validation block cannot
# see other variables, so the check lives here.
resource "terraform_data" "existing_vpc_inputs" {
  count = local.create_vpc ? 0 : 1

  lifecycle {
    precondition {
      condition     = length(var.private_subnet_ids) >= 2 && length(var.public_subnet_ids) >= 2
      error_message = "When vpc_id is set, private_subnet_ids and public_subnet_ids are both required, with at least two subnets each."
    }
  }
}

# Only looked up when we are going to check the tags: when tag_existing_subnets
# is set we are writing them, and when validation is off nothing reads this.
data "aws_subnet" "existing" {
  for_each = toset(local.validate_existing ? local.existing_subnet_ids : [])
  id       = each.value
}

# --- Option 1: apply the tags ------------------------------------------------

resource "aws_ec2_tag" "private_internal_elb" {
  for_each = toset(local.tag_existing ? var.private_subnet_ids : [])

  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "private_karpenter_discovery" {
  for_each = toset(local.tag_existing ? var.private_subnet_ids : [])

  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}

resource "aws_ec2_tag" "public_elb" {
  for_each = toset(local.tag_existing ? var.public_subnet_ids : [])

  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

# --- Option 2: check for them at plan time -----------------------------------

check "existing_subnet_discovery_tags" {
  assert {
    condition = !local.validate_existing || alltrue([
      for id in var.private_subnet_ids :
      lookup(data.aws_subnet.existing[id].tags, "karpenter.sh/discovery", null) == var.cluster_name
    ])
    error_message = <<-EOT
      Every subnet in private_subnet_ids must be tagged
      karpenter.sh/discovery = "${var.cluster_name}", or Karpenter will not
      discover them and no job nodes will be provisioned.

      Set tag_existing_subnets = true to have these modules apply the tag, or
      apply it yourself. To deploy without the check, set
      validate_existing_subnet_tags = false.
    EOT
  }

  assert {
    condition = !local.validate_existing || alltrue([
      for id in var.private_subnet_ids :
      lookup(data.aws_subnet.existing[id].tags, "kubernetes.io/role/internal-elb", null) != null
    ])
    error_message = <<-EOT
      Every subnet in private_subnet_ids must be tagged
      kubernetes.io/role/internal-elb, or the AWS Load Balancer Controller will
      not place an internal load balancer in them.

      Set tag_existing_subnets = true to have these modules apply the tag, or
      apply it yourself. To deploy without the check, set
      validate_existing_subnet_tags = false.
    EOT
  }

  assert {
    condition = !local.validate_existing || alltrue([
      for id in var.public_subnet_ids :
      lookup(data.aws_subnet.existing[id].tags, "kubernetes.io/role/elb", null) != null
    ])
    error_message = <<-EOT
      Every subnet in public_subnet_ids must be tagged kubernetes.io/role/elb,
      or the AWS Load Balancer Controller will not discover them and the
      platform Ingress will never get an ALB.

      Set tag_existing_subnets = true to have these modules apply the tag, or
      apply it yourself. To deploy without the check, set
      validate_existing_subnet_tags = false.
    EOT
  }
}
