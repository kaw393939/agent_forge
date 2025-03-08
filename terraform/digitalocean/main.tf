terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Create an SSH key for secure access
resource "digitalocean_ssh_key" "default" {
  name       = "${var.name_prefix}-${var.environment}-key"
  public_key = file(var.ssh_public_key_path)
}

# Create a VPC for network isolation
resource "digitalocean_vpc" "agent_forge" {
  name        = "${var.name_prefix}-vpc-${var.environment}"
  region      = var.region
  description = "VPC for ${var.name_prefix} ${var.environment} environment"
  ip_range    = "10.120.0.0/24"  # Changed to avoid conflict with DigitalOcean reserved range
}

# Create a Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "agent_forge" {
  name         = "${var.name_prefix}-cluster-${var.environment}"
  region       = var.region
  version      = var.kubernetes_version
  vpc_uuid     = digitalocean_vpc.agent_forge.id
  auto_upgrade = true
  ha           = var.environment == "prod" ? true : false

  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }

  node_pool {
    name       = "${var.name_prefix}-worker-pool"
    size       = var.node_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
    
    tags = [
      "${var.name_prefix}",
      var.environment,
      "k8s"
    ]
  }

  tags = [
    "${var.name_prefix}",
    var.environment,
    "k8s"
  ]
}

# Create a project to organize resources
# Map our environment values to DigitalOcean's accepted values
locals {
  do_environment_map = {
    "dev" = "development"
    "stage" = "staging"
    "prod" = "production"
  }
}

resource "digitalocean_project" "agent_framework" {
  name        = "${var.name_prefix}-${var.environment}"
  description = "Agent Framework project for ${var.environment} environment"
  purpose     = "Agent Framework Infrastructure"
  environment = lookup(local.do_environment_map, var.environment, "development")
  resources   = [digitalocean_kubernetes_cluster.agent_forge.urn]
}

# Create domain if provided
resource "digitalocean_domain" "default" {
  count = var.domain != "" ? 1 : 0
  name  = var.domain
}

# Output to get the kubeconfig for manual configuration
output "kubeconfig" {
  value     = digitalocean_kubernetes_cluster.agent_forge.kube_config[0].raw_config
  sensitive = true
}

# We won't use the data source for ingress_nginx as it would require the service to be deployed first
# Instead, we'll manually update DNS records after deployment

# We'll create DNS records after deployment using the update_dns.sh script
# This approach is safer as it ensures the load balancer IP is available

# Add Kubernetes provider to interact with the cluster
provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.agent_forge.endpoint
  token                  = digitalocean_kubernetes_cluster.agent_forge.kube_config[0].token
  cluster_ca_certificate = base64decode(digitalocean_kubernetes_cluster.agent_forge.kube_config[0].cluster_ca_certificate)
}

# Output the Kubernetes cluster ID
output "kubernetes_cluster_id" {
  value = digitalocean_kubernetes_cluster.agent_forge.id
}

# Output the Kubernetes cluster name
output "kubernetes_cluster_name" {
  value = digitalocean_kubernetes_cluster.agent_forge.name
}

# Output the Kubernetes version
output "kubernetes_version" {
  value = digitalocean_kubernetes_cluster.agent_forge.version
}

# Output the kubeconfig command to configure kubectl
output "kubeconfig_command" {
  value = "doctl kubernetes cluster kubeconfig save ${digitalocean_kubernetes_cluster.agent_forge.id}"
}

# Output the project ID
output "project_id" {
  value = digitalocean_project.agent_framework.id
}

# Output the Kubernetes cluster endpoint
output "kubernetes_endpoint" {
  value = digitalocean_kubernetes_cluster.agent_forge.endpoint
  sensitive = true
}

# We'll get the load balancer IP after deployment using kubectl

# Output application URLs if domain is provided
output "application_urls" {
  value = var.domain != "" ? {
    main     = "https://${var.domain}"
    www      = "https://www.${var.domain}"
    registry = "https://registry.${var.domain}"
    agent    = "https://agent.${var.domain}"
    tools    = "https://tools.${var.domain}"
    traefik  = "https://traefik.${var.domain}"
    linkerd  = "https://linkerd.${var.domain}"
  } : null
}
