data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Calculate the number of bits needed to divide the VPC CIDR
  # For public/private/intra subnets across multiple AZs
  az_count = length(var.azs)

  # Calculate subnet CIDRs for each AZ
  # This creates equally sized subnets for public, private, and intra networks
  public_subnet_cidrs  = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr_block, 4, i)]
  private_subnet_cidrs = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr_block, 4, i + local.az_count)]
  intra_subnet_cidrs   = [for i in range(local.az_count) : cidrsubnet(var.vpc_cidr_block, 4, i + (local.az_count * 2))]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = var.autoglue.autoglue_cluster_name
  cidr = var.vpc_cidr_block

  azs             = var.azs
  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs
  intra_subnets   = local.intra_subnet_cidrs

  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = false
  one_nat_gateway_per_az = var.enable_nat_gateway

  enable_dns_hostnames = true
  enable_dns_support   = true

  map_public_ip_on_launch = true

  tags = {
    Name        = var.autoglue.autoglue_cluster_name
    Environment = "production"
    ManagedBy   = "terraform"
  }

  public_subnet_tags = {
    Type = "public"
  }

  private_subnet_tags = {
    Type = "private"
  }

  intra_subnet_tags = {
    Type = "intra"
  }
}


module "vpc_endpoints" {
  source = "./modules/vpc-endpoints"

  create = var.enable_vpc_endpoints
  vpc_id = module.vpc.vpc_id

  create_security_group      = true
  security_group_name_prefix = "${var.autoglue.autoglue_cluster_name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
      subnet_ids = module.vpc.intra_subnets
      tags       = { Name = "s3-vpc-endpoint" }
    },
  }


}