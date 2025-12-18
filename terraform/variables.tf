variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "us-west-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "default"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "gluekube-aws"
}

variable "public_key" {
  sensitive = true
}

variable "master_node_count" {
  type = number
  default = 3
}

variable "worker_node_count" {
  type = number
  default = 6
}

variable "instance_type" {
  type = string
  default = "t3a.xlarge"
}

variable "autoglue_key" {
  type = string
  sensitive = true
}

variable "autoglue_org_id" {
  type = string
}


variable "autoglue_org_secret" {
  type = string
  sensitive = true
}

variable "zone_id" {
  type = string
  sensitive = true
}

variable "domain_name" {
  type = string
  sensitive = true
}


variable "aws_access_key_id_route53" {
  type = string
  sensitive = true
}

variable "aws_secret_access_key_route53" {
  type = string
  sensitive = true
}

variable "aws_access_key_id" {
  type = string
  sensitive = true
}

variable "aws_secret_access_key" {
  type = string
  sensitive = true
}