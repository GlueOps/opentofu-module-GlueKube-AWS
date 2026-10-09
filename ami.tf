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
  count       = var.ami_id == "" ? 1 : 0
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
      error_message = "Resolved AMI ${self.id} (${self.name}) is not a plain Ubuntu Server image (Ubuntu Pro or other billed product)."
    }
  }
}

locals {
  # Module-wide default AMI: var.ami_id when pinned, otherwise the latest Canonical image.
  ami_id = coalesce(var.ami_id, one(data.aws_ami.ubuntu[*].id))
}
