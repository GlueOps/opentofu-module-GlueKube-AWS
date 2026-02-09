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
  version = "~> 5.0"

  name = var.autoglue.autoglue_cluster_name
  cidr = var.vpc_cidr_block

  azs             = var.azs
  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs
  intra_subnets   = local.intra_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

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
