data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.autoglue.autoglue_cluster_name
  cidr = var.vpc_cidr_block

  azs             = [data.aws_availability_zones.available.names[0]]
  public_subnets  = [var.subnet_cidr]

  enable_nat_gateway = false
  single_nat_gateway = false
  one_nat_gateway_per_az = false

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
}
