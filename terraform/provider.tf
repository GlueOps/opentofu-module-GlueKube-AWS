terraform {
  required_providers {
    autoglue = {
      source = "registry.terraform.io/GlueOps/autoglue"
      version = "0.10.0"
    }
  }
}


provider "autoglue" {
  org_id = var.autoglue_org_id
  base_url = "https://autoglue.glueopshosted.com/api/v1"
  org_key = var.autoglue_key
  org_secret = var.autoglue_org_secret
}


provider "aws" {
  region  = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

provider "aws" {
  alias = "aws_route53"
  access_key = var.aws_access_key_id_route53
  secret_key = var.aws_secret_access_key_route53
  region  = var.aws_region
}