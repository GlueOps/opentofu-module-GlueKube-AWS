# Test instantiation of the GlueKube-AWS root module as `module "captain"`.
#
# The root module is consumed by local path (../../). All nested object inputs
# are assembled here from the flat variables in variables.tf, so the CI workflow
# can supply every value via TF_VAR_* secrets. Modeled on README.md usage block.

module "captain" {
  source = "../../"

  # --- network / compute ---
  vpc_cidr_block       = var.vpc_cidr_block
  azs                  = var.azs
  region               = var.aws_region
  enable_nat_gateway   = true
  enable_vpc_endpoints = var.enable_vpc_endpoints

  # --- AWS provider credentials ---
  provider_credentials = {
    name          = var.aws_provider_name
    access_key    = var.aws_access_key
    secret_key    = var.aws_secret_key
    region        = var.aws_region
    session_token = var.aws_session_token
  }

  # --- AutoGlue integration ---
  autoglue = {
    autoglue_cluster_name = var.autoglue_cluster_name

    credentials = {
      autoglue_key        = var.autoglue_key
      autoglue_org_secret = var.autoglue_org_secret
      base_url            = var.autoglue_base_url
    }

    route_53_config = {
      aws_access_key_id     = var.route53_aws_access_key_id
      aws_secret_access_key = var.route53_aws_secret_access_key
      aws_region            = var.route53_region
      domain_name           = var.domain_name
      zone_id               = var.route53_zone_id
      credential_id         = var.autoglue_credential_id
    }
  }

  # --- cluster metadata (forwarded to the autoglue-metadata module) ---
  cluster_metadata = {
    calico_network_calico_cidr = var.calico_cidr
    network_service_cidr       = var.service_cidr
    cloud                      = var.cloud
  }

  # --- bastion ---
  bastion = {
    instance_type = var.bastion_instance_type
    image         = var.bastion_ami
    create        = true
  }

  # --- node pools ---
  # Minimal, cost-conscious topology for a smoke test: a single attached master
  # pool. This satisfies the root module's validation that at least one pool has
  # role = "master" and attached = true (see ../../variables.tf).
  node_pools = [
    {
      name              = "test-master-pool"
      role              = "master"
      instance_type     = var.node_instance_type
      image             = var.node_ami
      node_count        = var.node_count
      subnet            = "private"
      attached          = true
      kubernetes_labels = {}
      kubernetes_taints = []
    }
  ]

  peering_configs = []
}
