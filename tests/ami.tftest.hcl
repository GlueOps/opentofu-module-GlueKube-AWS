# AMI selection tests. Plan-only, with every provider mocked, so they need no
# cloud credentials:  tofu init && tofu test
#
# The AMI lookups are overridden with fixed images, so these tests cover the
# module's AMI precedence logic, not Canonical's live catalogue.

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
