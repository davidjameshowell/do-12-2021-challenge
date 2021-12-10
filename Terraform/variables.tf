variable "do_token" {
  description = "Digital Ocean Read/Write Token"
}

variable "cluster_region" {
  type        = string
  description = "Region to create cluster in"
  default     = "sfo3"
}

variable "cluster_version" {
  type        = string
  description = "Digital Ocean Kubernetes cluster version to create (please see DO docs, these are not standard versions)"
  default     = "1.21.5-do.0"
}

variable "cluster_auto_upgrade" {
  type        = bool
  description = "True or false to determine if cluster auto upgrade during maintenance window."
  default     = true
}

variable "cluster_autoscale_min_nodes" {
  type        = number
  description = "Minimum nodes in a cluster node pool group"
  default     = 1
}

variable "cluster_autoscale_max_nodes" {
  type        = number
  description = "Maximum nodes in a cluster node pool group"
  default     = 5
}
