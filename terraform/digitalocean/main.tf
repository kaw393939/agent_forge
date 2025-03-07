provider "digitalocean" {
  token = var.do_token
}

# Create a new Kubernetes cluster
resource "digitalocean_kubernetes_cluster" "primary" {
  name    = "${var.name_prefix}-${var.environment}"
  region  = var.region
  version = var.kubernetes_version

  # Use the smallest node size for cost efficiency
  node_pool {
    name       = "${var.name_prefix}-node-pool"
    size       = var.droplet_size
    auto_scale = true
    min_nodes  = var.min_nodes
    max_nodes  = var.max_nodes
    
    # Use node labels to help with scheduling
    labels = {
      environment = var.environment
      service     = "agent-framework"
    }
  }

  # Enable auto-upgrade to keep the cluster secure
  maintenance_policy {
    start_time = "04:00"
    day        = "sunday"
  }
}

# Create a project to organize resources
resource "digitalocean_project" "agent_framework" {
  name        = "${var.name_prefix}-${var.environment}"
  description = "Agent Framework project for ${var.environment} environment"
  purpose     = "Agent Framework Infrastructure"
  environment = var.environment
  resources   = [digitalocean_kubernetes_cluster.primary.urn]
}

# Optionally create DNS records if domain is provided
resource "digitalocean_domain" "default" {
  count = var.domain != "" ? 1 : 0
  name  = var.domain
}

# Output the kubeconfig for use with kubectl
output "kubeconfig" {
  sensitive = true
  value     = digitalocean_kubernetes_cluster.primary.kube_config[0].raw_config
}

# Output the cluster endpoint
output "cluster_endpoint" {
  value = digitalocean_kubernetes_cluster.primary.endpoint
}

# Output the cluster ID
output "cluster_id" {
  value = digitalocean_kubernetes_cluster.primary.id
}

# Output the project ID
output "project_id" {
  value = digitalocean_project.agent_framework.id
}
