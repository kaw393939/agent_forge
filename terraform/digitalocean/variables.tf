variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix to add to resource names"
  type        = string
  default     = "agent-framework"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "1.27.4-do.0" # Choose an available version from DO
}

variable "droplet_size" {
  description = "Size of the droplets for the Kubernetes cluster (smallest options for cost efficiency)"
  type        = string
  default     = "s-1vcpu-2gb" # Smallest recommended size for K8s
}

variable "min_nodes" {
  description = "Minimum number of nodes in the cluster"
  type        = number
  default     = 1 # Start with single node for dev
}

variable "max_nodes" {
  description = "Maximum number of nodes in the cluster"
  type        = number
  default     = 2 # Limit to 2 nodes for cost efficiency
}

variable "domain" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = ""
}
