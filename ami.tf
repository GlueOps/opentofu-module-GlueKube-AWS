# Single source of the Ubuntu AMI used by the bastion and every node pool.
#
# Resolves to the latest Canonical Ubuntu Server 24.04 (Noble) amd64 image in the
# provider's region. Ubuntu Pro images are published by the same Canonical owner
# under "ubuntu-pro-*/" names and bill as "Ubuntu Pro Linux", so the anchored name
# filter, the platform-details filter and the postcondition all exclude them.
#
# Instances ignore later changes to their AMI (see lifecycle blocks), so a new
# Canonical release only affects instances created after it is published.
data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" && local.uses_default_ami ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "platform-details"
    values = ["Linux/UNIX"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  lifecycle {
    postcondition {
      condition     = self.platform_details == "Linux/UNIX" && self.usage_operation == "RunInstances"
      error_message = "Resolved AMI ${self.id} (${self.name}) is not a plain Ubuntu Server image (Ubuntu Pro or other billed product). Set ami_id to pin an Ubuntu Server AMI instead."
    }
  }
}

locals {
  # Whether any instance falls back to the module default (no per-resource pin).
  uses_default_ami = (var.bastion.create && var.bastion.image == "") || anytrue([for np in var.node_pools : np.image == ""])

  # Module-wide default AMI: var.ami_id when pinned, otherwise the latest Canonical
  # image. Null when every instance is pinned, so nothing is looked up.
  ami_id = var.ami_id != "" ? var.ami_id : one(data.aws_ami.ubuntu[*].id)

  # Every AMI pinned by the caller (ami_id, bastion.image, node_pools[].image).
  pinned_ami_ids = toset(compact(concat(
    [var.ami_id, var.bastion.create ? var.bastion.image : ""],
    [for np in var.node_pools : np.image],
  )))
}

# Pinned AMIs are not filtered like the latest lookup above, so the check below
# warns (without blocking the plan) when a pin is Ubuntu Pro or another
# non-Ubuntu-Server product, or can't be found. Check blocks don't support
# count/for_each on scoped data sources, so the lookups live at the top level;
# a pin that matches nothing just returns no ids, but a DescribeImages API error
# (e.g. missing ec2:DescribeImages permission) still fails the plan. Only images
# visible under these owners are found; Canonical's images (Server and Pro) are
# listed under the "amazon" alias, so AMIs shared from other accounts show up as
# not found.
data "aws_ami_ids" "pinned" {
  count              = length(local.pinned_ami_ids) > 0 ? 1 : 0
  owners             = ["self", "amazon", "aws-marketplace"]
  include_deprecated = true

  filter {
    name   = "image-id"
    values = local.pinned_ami_ids
  }
}

data "aws_ami_ids" "pinned_ubuntu_server" {
  count              = length(local.pinned_ami_ids) > 0 ? 1 : 0
  owners             = ["self", "amazon", "aws-marketplace"]
  include_deprecated = true

  filter {
    name   = "image-id"
    values = local.pinned_ami_ids
  }

  filter {
    name   = "platform-details"
    values = ["Linux/UNIX"]
  }

  filter {
    name   = "usage-operation"
    values = ["RunInstances"]
  }
}

check "pinned_ami_is_ubuntu_server" {
  assert {
    condition     = length(setsubtract(local.pinned_ami_ids, flatten(data.aws_ami_ids.pinned[*].ids))) == 0
    error_message = "Pinned AMI(s) ${join(", ", sort(setsubtract(local.pinned_ami_ids, flatten(data.aws_ami_ids.pinned[*].ids))))} not found in this region among images owned by self, amazon or aws-marketplace; verify the AMI exists in this region (AMI ids are region-specific) or unset the pin to use the latest Ubuntu Server."
  }

  assert {
    condition     = length(setsubtract(flatten(data.aws_ami_ids.pinned[*].ids), flatten(data.aws_ami_ids.pinned_ubuntu_server[*].ids))) == 0
    error_message = "Pinned AMI(s) ${join(", ", sort(setsubtract(flatten(data.aws_ami_ids.pinned[*].ids), flatten(data.aws_ami_ids.pinned_ubuntu_server[*].ids))))} are Ubuntu Pro or otherwise not Ubuntu Server. Existing instances are not changed, but new instances would use them; unset ami_id / bastion.image / node_pools[].image to use the latest Ubuntu Server."
  }
}
