# Agent Forge Infrastructure

A comprehensive framework for deploying and managing LLM-based agent applications across Docker (local development) and Kubernetes (production) environments. This system provides a complete setup for LLM-powered agents with a central registry, tools integration, and a user-friendly web interface.

## 📋 Table of Contents

- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Deployment Options](#deployment-options)
- [Getting Started](#getting-started)
- [Documentation](#documentation)
- [Troubleshooting](#troubleshooting)
- [Adding New Components](#adding-new-components)
- [License](#license)

## 🌟 Overview

Agent Forge provides a complete infrastructure for developing, testing, and deploying intelligent agent applications powered by Large Language Models (LLMs). The system supports:

- **Dual Deployment Paths**: Development with Docker Compose and production with Kubernetes/Helm
- **Cloud Deployment**: DigitalOcean using Terraform and Kubernetes
- **Service Discovery**: Centralized registry for agent and tool discoverability
- **SSL/TLS**: Automatic certificate management with Let's Encrypt
- **CI/CD Integration**: Automated workflows via GitHub Actions
- **Monitoring & Updates**: Automatic container updates with health checks

## 🏗️ System Architecture

The system consists of these core components:

### Core Services

- **Service Registry** (`registry.mywebclass.org`): Central database tracking available agents and tools
- **Example Agent** (`agent.mywebclass.org`): Demonstration LLM agent using OpenAI
- **Example Tool** (`tools.mywebclass.org`): Calculator API tool for demonstration
- **Streamlit Frontend** (`chat.mywebclass.org`): Web interface for interacting with agents
- **Main Website** (`mywebclass.org` and `www.mywebclass.org`): Landing page with links to services

### Infrastructure Components

- **Docker Development**: Traefik for routing and Watchtower for updates
- **Kubernetes Production**: NGINX Ingress, cert-manager, and custom Helm charts
- **Monitoring**: Linkerd service mesh for observability

## 🚀 Deployment Options

Agent Forge supports multiple deployment models:

### Local Development (Docker Compose)
Perfect for development and testing on your local machine.

### Production Deployment (Kubernetes/Helm)
For scalable production environments with high availability and security.

#### Current Kubernetes Deployment Structure
The system is currently deployed with the following structure:

- **Main Website**: A static landing page at `mywebclass.org` and `www.mywebclass.org`
- **Chat Interface**: Streamlit application at `chat.mywebclass.org`
- **Service Registry**: API and documentation at `registry.mywebclass.org`
- **Example Agent**: LLM-powered agent at `agent.mywebclass.org`
- **Example Tool**: Demonstration tool at `tools.mywebclass.org`

All services are secured with SSL certificates managed through cert-manager and Let's Encrypt.

### Hybrid Model
Use Docker for development and testing, then promote to Kubernetes for production.

## 🏁 Getting Started

### Prerequisites

- **Docker and Docker Compose**: For local development
- **kubectl and Helm**: For Kubernetes deployment
- **Terraform**: For cloud infrastructure provisioning
- **OpenAI API Key**: For LLM functionality
- **DigitalOcean Account**: For cloud deployment
- **Domain Name**: For production deployment with SSL/TLS
- **jq**: Command-line JSON processor for API interactions

### Automated Setup

We've created a comprehensive setup script to automate the deployment process:

```bash
./scripts/setup.sh
```

This script will:
1. Check for required dependencies
2. Guide you through setting up environment variables
3. Configure DNS settings if needed
4. Deploy the application locally or to DigitalOcean Kubernetes

### Manual Setup

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/agent-forge.git
   cd agent-forge
   ```

2. **Configure Environment**
   ```bash
   cp .env.template .env
   # Edit .env with your API keys and configuration
   ```

3. **Local Development**
   ```bash
   docker-compose up -d
   ```

4. **Build and Push Docker Images**
   ```bash
   # Standard build and push
   ./scripts/build_push_images.sh
   
   # Build only without pushing to Docker Hub
   ./scripts/build_push_images.sh --skip-push
   
   # Build for local use only (no Docker Hub login required)
   ./scripts/build_push_images.sh --local-only
   
   # Force rebuild even if images exist
   ./scripts/build_push_images.sh --force
   ```

5. **Production Deployment**
   ```bash
   # Deploy to DigitalOcean Kubernetes
   ./scripts/terraform_deploy.sh apply
   
   # Create a plan without applying
   ./scripts/terraform_deploy.sh plan
   
   # Destroy infrastructure when no longer needed
   ./scripts/terraform_deploy.sh destroy
   
   # Deploy with specific options
   ./scripts/terraform_deploy.sh --environment prod --domain yourdomain.com apply
   ```

6. **Test Deployment Process**
   ```bash
   # Test the full deployment cycle (destroy and recreate)
   ./scripts/test_deployment.sh
   ```

## 📚 Documentation

Detailed documentation is available in the `docs/` directory:

- [System Architecture](docs/architecture.md) - Detailed system design
- [Docker Deployment](docs/docker-deployment.md) - Docker-based deployment guide
- [Kubernetes Deployment](docs/kubernetes-deployment.md) - Kubernetes/Helm deployment guide
- [Configuration Guide](docs/configuration.md) - Configuration options and customization
- [DNS Setup](docs/dns-setup.md) - DNS configuration for domain connectivity
- [Troubleshooting Guide](docs/troubleshooting.md) - Common issues and solutions

### Deployment Scripts

The infrastructure includes several optimized deployment scripts:

- **setup.sh**: Main setup script for configuring and deploying the application
- **build_push_images.sh**: Build and push Docker images with flexible options
- **terraform_deploy.sh**: Deploy or destroy infrastructure on DigitalOcean
- **update_dns.sh**: Configure DNS records for your domain
- **test_deployment.sh**: Test the full deployment cycle

## ❓ Troubleshooting

For common issues and solutions, see the [Troubleshooting Guide](docs/troubleshooting.md).

### Common Commands

```bash
# Check container status (local development)
docker-compose ps

# View container logs (local development)
docker-compose logs -f

# Check Kubernetes pod status
kubectl get pods -n agent-forge

# View Kubernetes pod logs
kubectl logs -n agent-forge <pod-name>

# Check Ingress status
kubectl get ingress -n agent-forge

# Check certificate status
kubectl get certificates -n agent-forge

# Check Kubernetes secrets
kubectl get secrets -n agent-forge

# Create or update the agent-secrets for OpenAI
kubectl create secret generic agent-secrets --from-literal=openai-api-key=your-key-here -n agent-forge

# Restart a deployment after updating secrets
kubectl rollout restart deployment example-agent -n agent-forge
```

### DNS Verification

After deployment, you can verify your DNS configuration with:

```bash
dig +short yourdomain.com
dig +short www.yourdomain.com
```

DNS changes typically take 5-30 minutes to propagate globally.

## ➕ Adding New Components

### Adding New Agents or Tools

1. Create a new directory structure for your component
2. Add your component code with a Dockerfile
3. Update configuration files:
   - For Docker: Update `docker-compose.yml`
   - For Kubernetes: Add templates to `helm/agent-forge/templates/`
4. Update build scripts to include your new component
5. Deploy using the appropriate method for your environment

### Setting Up Required Secrets

The system requires the following Kubernetes secrets:

1. **agent-secrets**: Contains the OpenAI API key for the example agent
   ```bash
   kubectl create secret generic agent-secrets --from-literal=openai-api-key=your-openai-api-key -n agent-forge
   ```

2. **docker-hub-credentials**: For pulling Docker images from Docker Hub
   ```bash
   kubectl create secret docker-registry docker-hub-credentials \
     --docker-username=your-dockerhub-username \
     --docker-password=your-dockerhub-token \
     -n agent-forge
   ```

After updating secrets, restart the affected deployments:
```bash
kubectl rollout restart deployment example-agent -n agent-forge
```

## 🧪 Testing Your Deployment

After deployment, verify your services are working properly:

1. **Check all pods are running**:
   ```bash
   kubectl get pods -n agent-forge
   ```

2. **Verify services are accessible**:
   - Open `mywebclass.org` to see the main landing page
   - Navigate to `chat.mywebclass.org` to use the Streamlit interface
   - Check `registry.mywebclass.org` to view registered agents and tools

3. **Test agent functionality**:
   - Use the Streamlit interface to send queries to the agent
   - Check agent logs to verify proper API key configuration:
   ```bash
   kubectl logs -n agent-forge -l app=example-agent
   ```
   
4. **Verify DNS and certificate configuration**:
   ```bash
   kubectl get ingress -n agent-forge
   kubectl get certificates -n agent-forge
   ```

## 🔐 Security Considerations

1. **API Keys**: Never commit your `.env` file or any file containing API keys to Git
2. **Kubernetes Secrets**: Always use Kubernetes secrets for sensitive information
3. **Access Control**: Implement proper access controls for your Kubernetes cluster
4. **SSL/TLS**: Always use HTTPS for production deployments
5. **Regular Updates**: Keep all components updated to patch security vulnerabilities

## 📜 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👨‍💻 Maintainers

This project is maintained by Kevin Williams and the MyWebClass.org team. For questions or support, please open an issue on GitHub.

## 📦 GitHub Installation Guide

To install and run this project from GitHub, follow these steps:

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/agent-forge-infrastructure.git
cd agent-forge-infrastructure
```

### 2. Configure Environment Variables

```bash
cp .env.template .env
# Edit .env with your API keys and configuration
```

Required environment variables include:
- `OPENAI_API_KEY`: For the example agent functionality
- `DOCKER_HUB_TOKEN`: For pulling Docker images
- `DIGITAL_OCEAN_TOKEN`: For DigitalOcean Kubernetes deployment
- `GODADDY_API_KEY` and `GODADDY_API_SECRET`: For DNS configuration (if using GoDaddy)

### 3. Local Development Setup

```bash
# Build and run locally with Docker Compose
docker-compose up -d
```

### 4. Production Deployment Setup

```bash
# Set up DigitalOcean infrastructure using Terraform
cd terraform/digitalocean
terraform init
terraform apply

# Configure kubectl to use your DO cluster
doctl kubernetes cluster kubeconfig save your-cluster-name

# Deploy with Helm
cd ../../helm
helm install agent-forge ./agent-forge
```

### 5. Domain Configuration

After deployment, configure your domain DNS settings to point to your cluster's load balancer IP:

```bash
# Get the load balancer IP
kubectl get svc -n ingress-nginx

# Update DNS records for all domains to point to this IP
# - mywebclass.org
# - www.mywebclass.org
# - chat.mywebclass.org
# - registry.mywebclass.org
# - agent.mywebclass.org
# - tools.mywebclass.org
```
