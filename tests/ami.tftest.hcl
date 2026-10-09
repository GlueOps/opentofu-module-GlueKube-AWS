# AMI selection tests. Plan-only, with every provider mocked, so they need no
# cloud credentials:  tofu init && tofu test
#
# The AMI lookups are overridden with fixed images, so these tests cover the
# module's logic (precedence, the pinned-AMI check, input validation), not
# Canonical's live catalogue.

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id               = "ami-0aaaaaaaaaaaaaaaa"
      name             = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20261004"
      owner_id         = "099720109477"
      platform_details = "Linux/UNIX"
      usage_operation  = "RunInstances"
    }
  }

  # By default every pinned AMI is visible and is Ubuntu Server.
  mock_data "aws_ami_ids" {
    defaults = {
      ids = ["ami-0bbbbbbbbbbbbbbbb", "ami-0cccccccccccccccc"]
    }
  }
}

mock_provider "aws" {
  alias = "aws_route53"
}

mock_provider "autoglue" {}

variables {
  provider_credentials = { name = "aws", access_key = "x", secret_key = "x", region = "us-west-2" }
  vpc_cidr_block       = "10.98.0.0/16"
  azs                  = ["us-west-2a"]
  cluster_metadata = {
    calico_network_calico_cidr = "172.16.0.0/16"
    network_service_cidr       = "192.168.0.0/16"
    cloud                      = "aws"
  }
  autoglue = {
    autoglue_cluster_name = "ami-test"
    credentials           = { autoglue_key = "x", autoglue_org_secret = "x", base_url = "https://example.invalid" }
    route_53_config = {
      aws_access_key_id     = "x"
      aws_secret_access_key = "x"
      aws_region            = "us-west-2"
      domain_name           = "example.invalid"
      zone_id               = "Z0"
      credential_id         = "x"
    }
  }
  bastion = { instance_type = "t3a.medium" }
  node_pools = [
    { name = "m", role = "master", node_count = 1, instance_type = "c6a.large", kubernetes_taints = [] },
  ]
}

run "latest_by_default" {
  command = plan

  assert {
    condition     = aws_instance.bastion[0].ami == "ami-0aaaaaaaaaaaaaaaa" && local.ami_id == "ami-0aaaaaaaaaaaaaaaa"
    error_message = "With nothing pinned, the bastion and pools should use the latest lookup."
  }
}

run "ami_id_pins_everything" {
  command = plan

  variables {
    ami_id = "ami-0bbbbbbbbbbbbbbbb"
  }

  assert {
    condition     = aws_instance.bastion[0].ami == "ami-0bbbbbbbbbbbbbbbb" && local.ami_id == "ami-0bbbbbbbbbbbbbbbb"
    error_message = "ami_id should pin the bastion and the pools' default AMI."
  }

  assert {
    condition     = length(data.aws_ami.ubuntu) == 0
    error_message = "The latest lookup should be skipped when ami_id is set."
  }
}

run "bastion_image_beats_ami_id" {
  command = plan

  variables {
    ami_id  = "ami-0bbbbbbbbbbbbbbbb"
    bastion = { instance_type = "t3a.medium", image = "ami-0cccccccccccccccc" }
  }

  assert {
    condition     = aws_instance.bastion[0].ami == "ami-0cccccccccccccccc"
    error_message = "bastion.image should take precedence over ami_id."
  }
}

run "pins_are_collected" {
  command = plan

  variables {
    ami_id     = "ami-0bbbbbbbbbbbbbbbb"
    bastion    = { instance_type = "t3a.medium", image = "ami-0cccccccccccccccc" }
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "c6a.large", kubernetes_taints = [], image = "ami-0bbbbbbbbbbbbbbbb" }]
  }

  assert {
    condition     = local.pinned_ami_ids == toset(["ami-0bbbbbbbbbbbbbbbb", "ami-0cccccccccccccccc"])
    error_message = "Pinned AMIs should be the distinct non-empty ami_id / bastion.image / pool images."
  }
}

run "bastion_pin_ignored_without_bastion" {
  command = plan

  variables {
    bastion = { instance_type = "t3a.medium", image = "ami-0cccccccccccccccc", create = false }
  }

  assert {
    condition     = length(local.pinned_ami_ids) == 0 && length(data.aws_ami_ids.pinned) == 0
    error_message = "bastion.image should not be checked when no bastion is created."
  }
}

run "pro_pin_warns" {
  command = plan

  variables {
    bastion = { instance_type = "t3a.medium", image = "ami-0dddddddddddddddd" }
  }

  override_data {
    target = data.aws_ami_ids.pinned
    values = { ids = ["ami-0dddddddddddddddd"] }
  }

  override_data {
    target = data.aws_ami_ids.pinned_ubuntu_server
    values = { ids = [] }
  }

  expect_failures = [check.pinned_ami_is_ubuntu_server]
}

run "latest_lookup_rejects_pro" {
  command = plan

  override_data {
    target = data.aws_ami.ubuntu
    values = {
      id               = "ami-0eeeeeeeeeeeeeeee"
      name             = "ubuntu-pro-server/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-pro-server-20261004"
      platform_details = "Ubuntu Pro Linux"
      usage_operation  = "RunInstances:0g00"
    }
  }

  expect_failures = [data.aws_ami.ubuntu]
}

run "bad_ami_id_format" {
  command = plan

  variables {
    ami_id = "ubuntu-24.04"
  }

  expect_failures = [var.ami_id]
}

run "bad_bastion_image_format" {
  command = plan

  variables {
    bastion = { instance_type = "t3a.medium", image = "ami-XYZ" }
  }

  expect_failures = [var.bastion]
}

run "bad_pool_image_format" {
  command = plan

  variables {
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "c6a.large", kubernetes_taints = [], image = "ami-XYZ" }]
  }

  expect_failures = [var.node_pools]
}

run "graviton_pool_rejected" {
  command = plan

  variables {
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "m7gd.large", kubernetes_taints = [] }]
  }

  expect_failures = [var.node_pools]
}

run "graviton_bastion_rejected" {
  command = plan

  variables {
    bastion = { instance_type = "t4g.small" }
  }

  expect_failures = [var.bastion]
}

run "gpu_pool_allowed" {
  command = plan

  variables {
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "g4dn.xlarge", kubernetes_taints = [] }]
  }
}

# Node precedence: pool image > ami_id > latest.
run "node_uses_latest" {
  command = plan

  assert {
    condition     = module.node_pool["m"].instance_amis["0"] == "ami-0aaaaaaaaaaaaaaaa"
    error_message = "A pool without image should use the latest lookup."
  }
}

run "node_uses_ami_id" {
  command = plan

  variables {
    ami_id = "ami-0bbbbbbbbbbbbbbbb"
  }

  assert {
    condition     = module.node_pool["m"].instance_amis["0"] == "ami-0bbbbbbbbbbbbbbbb"
    error_message = "A pool without image should use ami_id."
  }
}

run "node_image_beats_ami_id" {
  command = plan

  variables {
    ami_id     = "ami-0bbbbbbbbbbbbbbbb"
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "c6a.large", kubernetes_taints = [], image = "ami-0cccccccccccccccc" }]
  }

  assert {
    condition     = module.node_pool["m"].instance_amis["0"] == "ami-0cccccccccccccccc"
    error_message = "A pool's image should take precedence over ami_id."
  }
}

run "lookup_skipped_when_everything_pinned" {
  command = plan

  variables {
    bastion    = { instance_type = "t3a.medium", image = "ami-0cccccccccccccccc" }
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "c6a.large", kubernetes_taints = [], image = "ami-0bbbbbbbbbbbbbbbb" }]
  }

  assert {
    condition     = length(data.aws_ami.ubuntu) == 0 && local.ami_id == null
    error_message = "The latest lookup should be skipped when no instance uses the default."
  }

  assert {
    condition     = aws_instance.bastion[0].ami == "ami-0cccccccccccccccc" && module.node_pool["m"].instance_amis["0"] == "ami-0bbbbbbbbbbbbbbbb"
    error_message = "Pinned instances should keep their own AMIs."
  }
}

run "missing_pin_warns" {
  command = plan

  variables {
    bastion = { instance_type = "t3a.medium", image = "ami-0ffffffffffffffff" }
  }

  override_data {
    target = data.aws_ami_ids.pinned
    values = { ids = [] }
  }

  override_data {
    target = data.aws_ami_ids.pinned_ubuntu_server
    values = { ids = [] }
  }

  expect_failures = [check.pinned_ami_is_ubuntu_server]
}

# arm64 types work when the caller pins its own (arm64) AMI.
run "graviton_pool_with_pinned_image_allowed" {
  command = plan

  variables {
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "c7g.large", kubernetes_taints = [], image = "ami-0bbbbbbbbbbbbbbbb" }]
  }

  assert {
    condition     = module.node_pool["m"].instance_amis["0"] == "ami-0bbbbbbbbbbbbbbbb"
    error_message = "A c7g pool with a pinned image should be allowed."
  }
}

run "graviton_pool_without_image_rejected" {
  command = plan

  variables {
    node_pools = [{ name = "m", role = "master", node_count = 1, instance_type = "c7g.large", kubernetes_taints = [] }]
  }

  expect_failures = [var.node_pools]
}

run "graviton_bastion_with_pinned_image_allowed" {
  command = plan

  variables {
    bastion = { instance_type = "t4g.small", image = "ami-0cccccccccccccccc" }
  }

  assert {
    condition     = aws_instance.bastion[0].ami == "ami-0cccccccccccccccc"
    error_message = "A t4g bastion with a pinned image should be allowed."
  }
}
