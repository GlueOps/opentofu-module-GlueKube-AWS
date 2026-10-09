# Canonical also publishes Ubuntu Pro under this owner ("ubuntu-pro-*/" names, billed
# as "Ubuntu Pro Linux"); the anchored name filter and platform-details exclude it.
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
}

locals {
  ami_id = coalesce(var.ami_id, one(data.aws_ami.ubuntu[*].id))
}
