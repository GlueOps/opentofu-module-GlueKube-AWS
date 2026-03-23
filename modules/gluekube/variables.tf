variable "vpc_id" {
  type        = string
  description = "The ID of the VPC"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to distribute nodes across"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "instance_type" {
  type        = string
  description = "The EC2 instance type"
}

variable "storage_size_gb" {
  type        = number
  description = "The size of the storage in GB"
  nullable    = false

  validation {
    condition     = var.storage_size_gb > 0
    error_message = "storage_size_gb must be a positive number of gigabytes."
  }
}

variable "image" {
  type        = string
  description = "The AMI ID to use for the instances"
  default     = ""
}

variable "region" {
  type        = string
  description = "The AWS region"
  default     = "us-west-2"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in this pool"
  default     = 1
}

variable "role" {
  type        = string
  description = "The role of the nodes (master or worker)"
}

variable "kubernetes_labels" {
  type        = map(string)
  description = "Kubernetes labels to apply to the nodes"
}

variable "kubernetes_annotations" {
  type        = map(string)
  description = "Kubernetes annotations to apply to the nodes"
  default     = {}
}

variable "kubernetes_taints" {
  type = list(object({
    key    = string
    value  = string
    effect = string
  }))
  description = "Kubernetes taints to apply to the nodes"
  default     = []
}

variable "name" {
  type        = string
  description = "Name of the node pool"
}

variable "cluster_name" {
  type        = string
  description = "Name of the cluster"
}
