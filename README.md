# opentofu-module-GlueKube-AWS

OpenTofu/Terraform module for deploying GlueKube clusters on AWS.

## Overview

This module creates a complete GlueKube Kubernetes cluster infrastructure on AWS, including:
- VPC with public and private subnets across 3 availability zones
- NAT gateways (one per AZ) for high availability
- EC2 instances distributed across multiple AZs
- Bastion server for secure access
- Security groups with appropriate firewall rules
- Integration with AutoGlue for cluster management
- Route53 DNS configuration

## Structure

The module follows the same pattern as the HetznerCloud module:

- `provider.tf` - Provider configuration for AWS and AutoGlue
- `variables.tf` - Input variables
- `network.tf` - VPC module configuration (3 AZs, NAT gateways)
- `bastion.tf` - Bastion server configuration
- `cluster.tf` - AutoGlue cluster and domain configuration
- `node_pool.tf` - Node pool module invocation
- `output.tf` - Output values
- `modules/gluekube/` - Reusable module for creating node pools
  - `node.tf` - EC2 instances distributed across AZs and security groups
  - `node_pool.tf` - AutoGlue node pool, labels, and taints
  - `variables.tf` - Module variables
  - `output.tf` - Module outputs
  - `cloudinit/` - Cloud-init configuration files

## Usage

```hcl
module "gluekube_aws" {
  source = "./opentofu-module-GlueKube-AWS"

  provider_credentials = {
    name       = "aws"
    access_key = var.aws_access_key_id
    secret_key = var.aws_secret_access_key
    region     = "us-west-2"
  }

  region          = "us-west-2"
  vpc_cidr_block  = "10.0.0.0/16"
  
  # Public subnets across 3 AZs
  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  # Private subnets across 3 AZs
  private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]

  bastion = {
    instance_type = "t3a.small"
    image         = ""  # Uses latest Ubuntu 24.04
  }

  autoglue = {
    autoglue_cluster_name = "my-cluster"

    credentials = {
      autoglue_key        = var.autoglue_key
      autoglue_org_secret = var.autoglue_org_secret
      base_url            = "https://autoglue.glueopshosted.com/api/v1"
    }

    route_53_config = {
      aws_access_key_id     = var.route53_access_key
      aws_secret_access_key = var.route53_secret_key
      aws_region            = "us-west-2"
      domain_name           = "example.com"
      zone_id               = "Z1234567890ABC"
      credential_id         = "cred-123"
    }
  }

  node_pools = [
    {
      name              = "masters"
      image             = ""  # Uses latest Ubuntu 24.04
      node_count        = 3
      instance_type     = "t3a.xlarge"
      role              = "master"
      kubernetes_labels = {}
      kubernetes_taints = []
    },
    {
      name              = "workers"
      image             = ""
      node_count        = 3
      instance_type     = "t3a.xlarge"
      role              = "worker"
      kubernetes_labels = {
        "node-role" = "worker"
      }
      kubernetes_taints = []
    }
  ]
}
```

## Requirements

- OpenTofu or Terraform >= 1.0
- AWS account with appropriate permissions
- AutoGlue account and credentials

## Features

- **High Availability**: Resources distributed across 3 availability zones
- **VPC Module**: Uses official AWS VPC module for best practices
- **NAT Gateways**: One NAT gateway per AZ for fault tolerance
- **Modular Design**: Node pools are created using a reusable module pattern
- **Flexible Configuration**: Support for multiple node pools with different configurations
- **Security**: Properly configured security groups with minimal required access
- **AutoGlue Integration**: Full integration with AutoGlue for cluster lifecycle management
- **Kubernetes Labels and Taints**: Support for custom labels and taints per node pool
- **Validation**: Input validation for CIDR blocks and node pool configurations

Managed by github-org-manager
