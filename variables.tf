variable "provider_credentials" {
  type = object({
    name          = string
    access_key    = string
    secret_key    = string
    region        = string
    session_token = optional(string)
  })
  description = "AWS provider credentials configuration"
}

variable "region" {
  type        = string
  description = "AWS region to deploy resources in"
  default     = "us-west-2"
}

variable "gluekube_docker_image" {
  type        = string
  description = "Docker image for GlueKube"
  default     = "ghcr.io/glueops/gluekube"
}

variable "gluekube_docker_tag" {
  type        = string
  description = "Docker tag for GlueKube"
  default     = "v0.0.12"
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC"
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr_block))
    error_message = "vpc_cidr_block must be a valid IPv4 CIDR block, for example: 10.0.0.0/16."
  }
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones for subnet distribution"
  validation {
    condition     = length(var.azs) > 0
    error_message = "At least one availability zone must be specified."
  }
}



variable "bastion" {
  description = "Bastion configuration."
  type = object({
    instance_type = string
    image         = string
    create        = optional(bool, true)
  })
}

variable "autoglue" {
  description = "Configuration for the AutoGlue platform integration, including cluster naming, credentials, and Route53 DNS settings."
  type = object({
    autoglue_cluster_name = string

    credentials = object({
      autoglue_key        = string
      autoglue_org_secret = string
      base_url            = string
    })

    route_53_config = object({
      aws_access_key_id     = string
      aws_secret_access_key = string
      aws_region            = string
      domain_name           = string
      zone_id               = string
      credential_id         = string
    })
  })
}

variable "node_pools" {
  type = list(object({
    name              = string
    image             = string
    node_count        = number
    instance_type     = string
    role              = string
    subnet            = optional(string, "private")
    kubernetes_labels = map(string)
    kubernetes_taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))

  description = "List of node pools to create"

  validation {
    condition     = length([for np in var.node_pools : np if np.role == "master"]) > 0
    error_message = "At least one node pool must have role = 'master'."
  }


  validation {
    condition     = alltrue([for np in var.node_pools : contains(["public", "private", "intra"], np.subnet)])
    error_message = "subnet must be one of: public, private, or intra."
  }
}
variable "peering_configs" {
  description = "A list of maps containing VPC peering configuration details"
  type = list(object({
    vpc_peering_connection_id = string
    destination_cidr_block    = string
    include_intra_routes      = optional(bool, false)
  }))
  default = []
}