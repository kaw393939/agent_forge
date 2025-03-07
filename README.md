# Agent Framework Infrastructure

This repository contains infrastructure code for deploying and managing LLM agent applications using a service mesh architecture with Linkerd, Traefik, and Watchtower.

## Overview

This framework provides:

- Multi-cloud deployment capabilities (AWS, GCP, Azure) using Terraform
- Kubernetes-based orchestration for agent workloads
- Service discovery for LLM agents and API tools
- Local development environment setup
- CI/CD pipelines using GitHub Actions
- Traefik for ingress and routing
- Watchtower for automatic container updates

## Architecture

The system uses Linkerd service mesh to connect various agents and services, with automatic discovery mechanisms allowing agents to find and use available API tools deployed as Docker containers.

Key components:
- **Linkerd Service Mesh**: Provides service-to-service communication
- **Traefik**: Handles ingress and routing
- **Watchtower**: Manages automatic updates to containers
- **Agent Registry**: Enables discovery of available agents
- **API Tool Registry**: Enables discovery of available API tools

## Getting Started

### Prerequisites

- Docker and Docker Compose
- kubectl
- Terraform
- GitHub account (for CI/CD)

### Local Development

```bash
# Clone the repository
git clone https://github.com/yourusername/agent-framework.git
cd agent-framework

# Start local development environment
./scripts/setup-local.sh
```

### Deployment

The framework supports deployment to multiple cloud providers:

```bash
# Deploy to AWS
cd terraform/aws
terraform init
terraform apply

# Deploy to GCP
cd terraform/gcp
terraform init
terraform apply

# Deploy to Azure
cd terraform/azure
terraform init
terraform apply
```

## Adding New Agents

To add a new agent, use the provided template:

```bash
./scripts/create-agent.sh my-new-agent
```

This will create the necessary files in the `agents/my-new-agent` directory.

## Adding New API Tools

To add a new API tool, use the provided template:

```bash
./scripts/create-api-tool.sh my-new-tool
```

This will create the necessary files in the `tools/my-new-tool` directory.

## License

MIT
