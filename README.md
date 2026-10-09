# opentofu-module-GlueKube-AWS

OpenTofu/Terraform module for deploying GlueKube clusters on AWS.

## Overview

This module creates a complete GlueKube Kubernetes cluster infrastructure on AWS, including:
- VPC with public, private, and intra subnets automatically distributed across availability zones
- Automatic CIDR block subdivision for optimal subnet allocation
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
- `network.tf` - VPC module configuration with automatic subnet CIDR calculation
- `ami.tf` - The single Ubuntu AMI lookup shared by the bastion and node pools
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
module "captain" {
  source                = "git::https://github.com/GlueOps/opentofu-module-GlueKube-AWS.git?ref=v0.4.1" # x-release-please-version
  gluekube_docker_image = "ghcr.io/glueops/gluekube"
  gluekube_docker_tag   = "v1.34.11-gluekube.7"
  vpc_cidr_block        = "10.16.0.0/16"
  azs                   = ["us-west-2a", "us-west-2b", "us-west-2c"]
  region                = var.provider_credentials.region
  enable_nat_gateway    = true # this should create a nat on each az defined above

  cluster_metadata = {
    calico_network_calico_cidr = "172.16.0.0/16"
    network_service_cidr       = "192.168.0.0/16"
    cloud                      = "aws"
  }

  provider_credentials = var.provider_credentials
  autoglue = {
    autoglue_cluster_name = var.autoglue_cluster_name

    credentials = {
      autoglue_key        = var.autoglue_key
      autoglue_org_secret = var.autoglue_org_secret
      base_url            = var.autoglue_base_url
    }
    route_53_config = {
      aws_access_key_id     = var.aws_access_key_id
      aws_secret_access_key = var.aws_secret_access_key
      aws_region            = var.route53_region
      domain_name           = var.domain_name
      zone_id               = var.route53_zone_id
      credential_id         = var.autoglue_credentials_id
    }
  }
  bastion = {
    instance_type = "t3a.medium"
    image         = "" # optional AMI pin; empty uses ami_id or the latest Ubuntu Server 24.04 AMI
    create        = true
  }

  node_pools = [
    {
      "instance_type" : "c6a.large",
      "role" : "master",
      "name" : "master-node-pool-1",
      "node_count" : 3,
      "subnet" : "private",
      "kubernetes_labels" : {},
      "kubernetes_taints" : []
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "glueops-platform-node-pool",
      "subnet" : "private",
      "node_count" : 3,

      "kubernetes_labels" : {
        "glueops.dev/role" : "glueops-platform"
      },
      "kubernetes_taints" : [
        {
          key    = "glueops.dev/role"
          value  = "glueops-platform"
          effect = "NoSchedule"
        }
      ]
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "clusterwide-node-pool-4",
      "subnet" : "private",
      "node_count" : 2,

      "kubernetes_labels" : {},
      "kubernetes_taints" : []
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "platform-loadbalancer-node-pool",
      "subnet" : "public",
      "node_count" : 2,

      "kubernetes_labels" : {
        "use-as-loadbalancer" : "platform-traefik",
      },
      "kubernetes_taints" : [
        {
          key    = "dedicated"
          value  = "platform-traefik"
          effect = "NoSchedule"
        }
      ],
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "public-loadbalancer-node-pool",
      "subnet" : "public",
      "node_count" : 2,

      "kubernetes_labels" : {
        "use-as-loadbalancer" : "public-traefik",
      },
      "kubernetes_taints" : [
        {
          key    = "dedicated"
          value  = "public-traefik"
          effect = "NoSchedule"
        }
      ],
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "nginx-loadbalancer-node-pool",
      "subnet" : "public",
      "node_count" : 2,

      "kubernetes_labels" : {
        "use-as-loadbalancer" : "public",
      },
      "kubernetes_taints" : [
        {
          key    = "dedicated"
          value  = "public"
          effect = "NoSchedule"
        }
      ],
    }
  ]
  peering_configs = []
}
```

## AMI selection

The bastion and every node pool share one AMI definition (`ami.tf`): the latest
Canonical **Ubuntu Server** 24.04 (Noble) amd64 image in the provider's region
(owner `099720109477`, name `ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*`).
Ubuntu Pro images are excluded by the name filter, a `platform-details = Linux/UNIX`
filter and a postcondition on the billing code. No AMI ids are hard-coded, so it works in any region.

| Priority | Bastion | Node pool |
|----------|---------|-----------|
| 1 | `bastion.image` (if non-empty) | pool `image` (if non-empty) |
| 2 | `ami_id` (if non-empty) | `ami_id` (if non-empty) |
| 3 | latest Ubuntu Server 24.04 amd64 | latest Ubuntu Server 24.04 amd64 |

Instances ignore AMI changes (`lifecycle { ignore_changes = [ami] }`): a new Canonical
release, or a changed `ami_id` / `image`, never replaces an existing bastion or node.
Only instances created afterwards (new pools, a larger `node_count`, or a replaced
instance) use the new AMI. To roll existing nodes onto a new AMI, replace them
deliberately (e.g. `tofu apply -replace=...`) one at a time.

- `ami_id`, `bastion.image` and `node_pools[].image` must be empty or an AMI ID (`ami-...`).
- Pinned AMIs are not filtered like the latest lookup. A `check` warns (without blocking
  the plan) when a pinned AMI is Ubuntu Pro or otherwise not Ubuntu Server.
- `bastion.image` is honoured (it was previously ignored), so a stale or Pro pin would be
  used the next time the bastion is created. Leave it empty unless you need a specific AMI.
- **amd64 only**: the module resolves x86_64 AMIs, so Graviton/arm64 instance types
  (e.g. `t4g`, `c7g`, `m7gd`, `r8g`, `a1`) are rejected for the bastion and node pools.

## Requirements

- OpenTofu or Terraform >= 1.0
- AWS account with appropriate permissions
- AutoGlue account and credentials

## Features

- **High Availability**: Resources distributed across configurable availability zones
- **Automatic Subnet Allocation**: CIDR blocks automatically calculated from VPC CIDR for public, private, and intra subnets
- **VPC Module**: Uses official AWS VPC module for best practices
- **NAT Gateways**: One NAT gateway per AZ for fault tolerance
- **Modular Design**: Node pools are created using a reusable module pattern
- **Flexible Configuration**: Support for multiple node pools with different configurations
- **Security**: Properly configured security groups with minimal required access
- **AutoGlue Integration**: Full integration with AutoGlue for cluster lifecycle management
- **Kubernetes Labels and Taints**: Support for custom labels and taints per node pool
- **Validation**: Input validation for CIDR blocks and node pool configurations


<!-- BEGIN_TF_DOCS -->
# opentofu-module-GlueKube-AWS

This opentofu module deploys a Kubernetes cluster on AWS using GlueKube.

```hcl

module "captain" {
  source                = "git::https://github.com/GlueOps/opentofu-module-GlueKube-AWS.git?ref=v0.4.1" # x-release-please-version
  gluekube_docker_image = "ghcr.io/glueops/gluekube"
  gluekube_docker_tag   = "v1.34.11-gluekube.7"

  provider_credentials = var.provider_credentials

  vpc_cidr_block     = "10.0.0.0/16"
  azs                = ["us-west-2a", "us-west-2b", "us-west-2c"]
  region             = var.provider_credentials.region
  enable_nat_gateway = true

  cluster_metadata = {
    calico_network_calico_cidr = "172.16.0.0/16"
    network_service_cidr       = "192.168.0.0/16"
    cloud                      = "aws"
  }

  bastion = {
    instance_type = "t3.large"
    image         = "" # optional AMI pin; empty uses ami_id or the latest Ubuntu Server 24.04 AMI
    create        = true # set false to skip the bastion host entirely
  }

  autoglue = {
    autoglue_cluster_name = var.autoglue_cluster_name

    credentials = {
      autoglue_key        = var.autoglue_key
      autoglue_org_secret = var.autoglue_org_secret
      base_url            = var.autoglue_base_url
    }

    route_53_config = {
      aws_access_key_id     = var.aws_access_key_id
      aws_secret_access_key = var.aws_secret_access_key
      aws_region            = var.route53_region
      domain_name           = var.domain_name
      zone_id               = var.route53_zone_id
      credential_id         = var.autoglue_credentials_id
    }
  }

  node_pools = [
    {
      "instance_type" : "c6a.large",
      "role" : "master",
      "name" : "master-node-pool-1",
      "node_count" : 3,
      "subnet" : "private",
      "kubernetes_labels" : {},
      "kubernetes_taints" : []
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "glueops-platform-node-pool",
      "subnet" : "private",
      "node_count" : 3,

      "kubernetes_labels" : {
        "glueops.dev/role" : "glueops-platform"
      },
      "kubernetes_taints" : [
        {
          key    = "glueops.dev/role"
          value  = "glueops-platform"
          effect = "NoSchedule"
        }
      ]
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "clusterwide-node-pool-4",
      "subnet" : "private",
      "node_count" : 2,

      "kubernetes_labels" : {},
      "kubernetes_taints" : []
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "platform-loadbalancer-node-pool",
      "subnet" : "public",
      "node_count" : 2,

      "kubernetes_labels" : {
        "use-as-loadbalancer" : "platform-traefik",
      },
      "kubernetes_taints" : [
        {
          key    = "dedicated"
          value  = "platform-traefik"
          effect = "NoSchedule"
        }
      ],
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "public-loadbalancer-node-pool",
      "subnet" : "public",
      "node_count" : 2,

      "kubernetes_labels" : {
        "use-as-loadbalancer" : "public-traefik",
      },
      "kubernetes_taints" : [
        {
          key    = "dedicated"
          value  = "public-traefik"
          effect = "NoSchedule"
        }
      ],
    },
    {
      "instance_type" : "c6a.large",
      "role" : "worker",
      "name" : "nginx-loadbalancer-node-pool",
      "subnet" : "public",
      "node_count" : 2,

      "kubernetes_labels" : {
        "use-as-loadbalancer" : "public",
      },
      "kubernetes_taints" : [
        {
          key    = "dedicated"
          value  = "public"
          effect = "NoSchedule"
        }
      ],
    }
  ]
}
```

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_autoglue"></a> [autoglue](#requirement\_autoglue) | 0.10.12 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.53, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_autoglue"></a> [autoglue](#provider\_autoglue) | 0.10.12 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.53, < 7.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_cluster_metadata"></a> [cluster\_metadata](#module\_cluster\_metadata) | git::https://github.com/GlueOps/opentofu-module-autoglue-metadata.git | v0.0.2 |
| <a name="module_node_pool"></a> [node\_pool](#module\_node\_pool) | ./modules/gluekube | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |
| <a name="module_vpc_endpoints"></a> [vpc\_endpoints](#module\_vpc\_endpoints) | ./modules/vpc-endpoints | n/a |
| <a name="module_vpc_peering_accepter_with_routes"></a> [vpc\_peering\_accepter\_with\_routes](#module\_vpc\_peering\_accepter\_with\_routes) | ./modules/vpc_peering_accepter_with_routes | n/a |

## Resources

| Name | Type |
|------|------|
| autoglue_cluster.cluster | resource |
| autoglue_cluster_bastion.bastion | resource |
| autoglue_cluster_captain_domain.domain | resource |
| autoglue_cluster_control_plane_record_set.ctrl_record | resource |
| autoglue_cluster_node_pools.autoglue_cluster_node_pools | resource |
| autoglue_domain.captain | resource |
| autoglue_record_set.cluster_record | resource |
| autoglue_server.bastion | resource |
| autoglue_ssh_key.bastion | resource |
| [aws_instance.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.bastion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ami.ubuntu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami_ids.pinned](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_ami_ids.pinned_ubuntu_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami_ids) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to pin for the bastion and every node pool that does not set its own image. Empty (default) uses the latest Canonical Ubuntu Server 24.04 amd64 AMI in the region. Changing it never replaces existing instances; only new instances use it. | `string` | `""` | no |
| <a name="input_autoglue"></a> [autoglue](#input\_autoglue) | Configuration for the AutoGlue platform integration, including cluster naming, credentials, and Route53 DNS settings. | <pre>object({<br/>    autoglue_cluster_name = string<br/><br/>    credentials = object({<br/>      autoglue_key        = string<br/>      autoglue_org_secret = string<br/>      base_url            = string<br/>    })<br/><br/>    route_53_config = object({<br/>      aws_access_key_id     = string<br/>      aws_secret_access_key = string<br/>      aws_region            = string<br/>      domain_name           = string<br/>      zone_id               = string<br/>      credential_id         = string<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_azs"></a> [azs](#input\_azs) | List of availability zones for subnet distribution | `list(string)` | n/a | yes |
| <a name="input_bastion"></a> [bastion](#input\_bastion) | Bastion configuration. image pins the bastion's AMI; empty (default) uses ami\_id or the latest Canonical Ubuntu Server 24.04 AMI. Changing it never replaces an existing bastion. | <pre>object({<br/>    instance_type = string<br/>    image         = optional(string, "")<br/>    create        = optional(bool, true)<br/>  })</pre> | n/a | yes |
| <a name="input_cluster_metadata"></a> [cluster\_metadata](#input\_cluster\_metadata) | Structured cluster metadata passed through to the autoglue-metadata module. All fields are required unless noted:<br/>  - calico\_network\_calico\_cidr: CIDR block for the Calico pod network (e.g. "10.244.0.0/16").<br/>  - network\_service\_cidr:       CIDR block for Kubernetes services (e.g. "10.96.0.0/12").<br/>  - cloud:                      Target cloud provider. One of: "aws", "proxmox", "hetzner".<br/>  - cloud\_vars:                 Optional map of cloud-specific overrides. When cloud is "proxmox",<br/>                                "calico\_node\_address\_autodetection\_v4" is required. | <pre>object({<br/>    calico_network_calico_cidr = string<br/>    network_service_cidr       = string<br/>    cloud                      = string<br/>    cloud_vars                 = optional(map(string), {}) # Holds the cloud-specific overrides<br/>  })</pre> | n/a | yes |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Whether to enable NAT Gateway | `bool` | `true` | no |
| <a name="input_enable_vpc_endpoints"></a> [enable\_vpc\_endpoints](#input\_enable\_vpc\_endpoints) | Whether to create the VPC endpoints (e.g. the S3 gateway endpoint). | `bool` | `true` | no |
| <a name="input_gluekube_docker_image"></a> [gluekube\_docker\_image](#input\_gluekube\_docker\_image) | Docker image for GlueKube | `string` | `"ghcr.io/glueops/gluekube"` | no |
| <a name="input_gluekube_docker_tag"></a> [gluekube\_docker\_tag](#input\_gluekube\_docker\_tag) | Docker tag for GlueKube | `string` | `"v1.34.11-gluekube.7"` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | List of node pools to create. image pins a pool's AMI; empty (default) uses ami\_id or the latest Canonical Ubuntu Server 24.04 AMI. Changing it never replaces existing nodes; only new nodes use it. | <pre>list(object({<br/>    name                   = string<br/>    image                  = optional(string, "")<br/>    node_count             = number<br/>    instance_type          = string<br/>    storage_size_gb        = optional(number, 30)<br/>    role                   = string<br/>    subnet                 = optional(string, "private")<br/>    kubernetes_labels      = optional(map(string), {})<br/>    kubernetes_annotations = optional(map(string), {})<br/>    kubernetes_taints = list(object({<br/>      key    = string<br/>      value  = string<br/>      effect = string<br/>    }))<br/>    attached = optional(bool, true)<br/>  }))</pre> | n/a | yes |
| <a name="input_peering_configs"></a> [peering\_configs](#input\_peering\_configs) | A list of maps containing VPC peering configuration details | <pre>list(object({<br/>    vpc_peering_connection_id = string<br/>    destination_cidr_block    = string<br/>    include_intra_routes      = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_provider_credentials"></a> [provider\_credentials](#input\_provider\_credentials) | AWS provider credentials configuration | <pre>object({<br/>    name          = string<br/>    access_key    = string<br/>    secret_key    = string<br/>    region        = string<br/>    session_token = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources in | `string` | `"us-west-2"` | no |
| <a name="input_vpc_cidr_block"></a> [vpc\_cidr\_block](#input\_vpc\_cidr\_block) | The CIDR block for the VPC | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
