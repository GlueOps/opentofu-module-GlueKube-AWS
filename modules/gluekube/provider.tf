terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    autoglue = {
      source = "registry.terraform.io/GlueOps/autoglue"
    }
  }
}
