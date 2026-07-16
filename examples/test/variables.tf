# Flat, scalar-only variables for the test example.
#
# These map cleanly to TF_VAR_* environment variables so the GitHub Actions
# workflow can inject real values from repo secrets at runtime. The nested
# object inputs the root module expects (provider_credentials, autoglue,
# cluster_metadata, bastion) are assembled from these in main.tf.
#
# No secret has a default — those must be supplied via secrets / a tfvars file.

################################
# AWS provider credentials
################################
variable "aws_access_key" {
  type        = string
  description = "AWS access key for the primary provider."
  sensitive   = true

}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key for the primary provider."
  sensitive   = true
}

variable "aws_session_token" {
  type        = string
  description = "Optional AWS session token (for temporary credentials)."
  default     = null
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region to deploy the cluster into."
  default     = "us-west-2"
}

variable "aws_provider_name" {
  type        = string
  description = "Cluster provider name registered in AutoGlue (provider_credentials.name)."
  default     = "aws"
}

################################
# Network / compute
################################
variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the test VPC."
  default     = "10.16.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones for subnet distribution."
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "node_ami" {
  type        = string
  description = "AMI id for node pool instances (Ubuntu 24.04 in the target region)."
}

variable "node_instance_type" {
  type        = string
  description = "EC2 instance type for the master node pool."
  default     = "c6a.large"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the master pool (kept low for cheap testing)."
  default     = 1
}

variable "bastion_ami" {
  type        = string
  description = "AMI id for the bastion host (Ubuntu 24.04 in the target region)."
}

variable "bastion_instance_type" {
  type        = string
  description = "EC2 instance type for the bastion host."
  default     = "t3a.medium"
}

################################
# AutoGlue integration
################################
variable "autoglue_cluster_name" {
  type        = string
  description = "Cluster name to register in AutoGlue."
}

variable "autoglue_key" {
  type        = string
  description = "AutoGlue org key."
  sensitive   = true
}

variable "autoglue_org_secret" {
  type        = string
  description = "AutoGlue org secret."
  sensitive   = true
}

variable "autoglue_base_url" {
  type        = string
  description = "Base URL of the AutoGlue API."
}

################################
# Route53 config (AutoGlue captain domain)
################################
variable "route53_aws_access_key_id" {
  type        = string
  description = "AWS access key id used by AutoGlue for Route53 management."
  sensitive   = true
}

variable "route53_aws_secret_access_key" {
  type        = string
  description = "AWS secret access key used by AutoGlue for Route53 management."
  sensitive   = true
}

variable "route53_region" {
  type        = string
  description = "AWS region for the Route53 provider."
  default     = "us-west-2"
}

variable "domain_name" {
  type        = string
  description = "Domain name for the captain domain."
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 hosted zone id for the domain."
}

variable "autoglue_credential_id" {
  type        = string
  description = "AutoGlue credential id referencing the Route53 credentials."
}

################################
# Cluster metadata (passed to autoglue-metadata module)
################################
variable "calico_cidr" {
  type        = string
  description = "CIDR block for the Calico pod network."
  default     = "172.16.0.0/16"
}

variable "service_cidr" {
  type        = string
  description = "CIDR block for Kubernetes services."
  default     = "192.168.0.0/16"
}

variable "cloud" {
  type        = string
  description = "Target cloud provider for cluster metadata (aws, proxmox, hetzner)."
  default     = "aws"
}
