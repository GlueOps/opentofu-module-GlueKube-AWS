terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    autoglue = {
      source  = "registry.terraform.io/GlueOps/autoglue"
      version = "0.10.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
