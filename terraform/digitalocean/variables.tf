variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "name_prefix" {
  description = "Prefix to add to resource names"
  type        = string
  default     = "agent-forge"
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
  description = "Kubernetes version for the DigitalOcean cluster"
  type        = string
  default     = "1.32.2-do.0"  # Updated to latest supported version
}

variable "node_size" {
  description = "Size of the Kubernetes worker nodes"
  type        = string
  default     = "s-2vcpu-4gb" # Standard size for Kubernetes workloads
}

variable "min_nodes" {
  description = "Minimum number of nodes for the Kubernetes cluster"
  type        = number
  default     = 1
}

variable "max_nodes" {
  description = "Maximum number of nodes for the Kubernetes cluster"
  type        = number
  default     = 3
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key for DigitalOcean droplet access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "ssh_private_key_path" {
  description = "Path to the private SSH key for DigitalOcean droplet access (used in output)"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "domain" {
  description = "Domain name for the application (optional)"
  type        = string
  default     = "mywebclass.org"
}

variable "docker_hub_username" {
  description = "Docker Hub username for pulling images"
  type        = string
  default     = "kaw393939"
}

variable "docker_hub_token" {
  description = "Docker Hub token for authentication"
  type        = string
  sensitive   = true
  default     = ""
}
