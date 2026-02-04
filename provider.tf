terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    autoglue = {
      source  = "registry.terraform.io/GlueOps/autoglue"
      version = "0.10.0"
    }
  }
}

provider "aws" {
  region     = var.provider_credentials.region
  access_key = var.provider_credentials.access_key
  secret_key = var.provider_credentials.secret_key
  token      = var.provider_credentials.session_token
}

provider "autoglue" {
  base_url   = var.autoglue.credentials.base_url
  org_key    = var.autoglue.credentials.autoglue_key
  org_secret = var.autoglue.credentials.autoglue_org_secret
}

provider "aws" {
  alias      = "aws_route53"
  region     = var.autoglue.route_53_config.aws_region
  access_key = var.autoglue.route_53_config.aws_access_key_id
  secret_key = var.autoglue.route_53_config.aws_secret_access_key
}
