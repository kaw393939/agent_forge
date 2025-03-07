#!/bin/bash
set -e

# DigitalOcean Installation Script
# Sets up the agent framework infrastructure on DigitalOcean

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default values
ENV="dev"
NAME_PREFIX="agent-framework"
MIN_NODES=1
MAX_NODES=2
REGION="nyc1"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --token=*)
        DO_TOKEN="${arg#*=}"
        shift
        ;;
        --env=*)
        ENV="${arg#*=}"
        shift
        ;;
        --name=*)
        NAME_PREFIX="${arg#*=}"
        shift
        ;;
        --region=*)
        REGION="${arg#*=}"
        shift
        ;;
        --min-nodes=*)
        MIN_NODES="${arg#*=}"
        shift
        ;;
        --max-nodes=*)
        MAX_NODES="${arg#*=}"
        shift
        ;;
    esac
done

# Check for required arguments
if [ -z "$DO_TOKEN" ]; then
    echo "❌ DigitalOcean API token is required."
    echo "Use --token=<token> to provide your DigitalOcean API token"
    exit 1
fi

echo "🔧 Setting up Agent Framework on DigitalOcean..."
echo "Environment: $ENV"
echo "Region: $REGION"
echo "Nodes: $MIN_NODES-$MAX_NODES"

# Ensure doctl is authenticated
echo "🔑 Authenticating with DigitalOcean API..."
doctl auth init -t "$DO_TOKEN"

# Change to Terraform directory
cd "$REPO_ROOT/terraform/digitalocean"

# Export variables for Terraform
export TF_VAR_do_token="$DO_TOKEN"
export TF_VAR_environment="$ENV"
export TF_VAR_name_prefix="$NAME_PREFIX"
export TF_VAR_region="$REGION"
export TF_VAR_min_nodes="$MIN_NODES"
export TF_VAR_max_nodes="$MAX_NODES"

# Initialize Terraform
echo "🏗️ Initializing Terraform..."
terraform init

# Apply Terraform configuration
echo "🚀 Creating infrastructure..."
terraform apply -auto-approve

# Get cluster ID and save kubeconfig
CLUSTER_ID=$(terraform output -raw cluster_id)

echo "☸️ Configuring kubectl..."
doctl kubernetes cluster kubeconfig save "$CLUSTER_ID"

# Set up Linkerd
echo "🔗 Installing Linkerd service mesh..."
if ! command -v linkerd &> /dev/null; then
    echo "⬇️ Downloading Linkerd CLI..."
    curl -sL https://run.linkerd.io/install | sh
    export PATH=$PATH:$HOME/.linkerd2/bin
fi

linkerd check --pre
linkerd install | kubectl apply -f -
linkerd check

# Set up Traefik
echo "🔀 Installing Traefik ingress controller..."
kubectl create namespace traefik || true
kubectl apply -f "$REPO_ROOT/kubernetes/base/traefik.yaml"

# Set up Watchtower
echo "🔄 Installing Watchtower for automatic updates..."
kubectl apply -f "$REPO_ROOT/kubernetes/base/watchtower.yaml"

# Deploy service registry
echo "📚 Deploying service registry..."
kubectl apply -f "$REPO_ROOT/kubernetes/base/service-registry.yaml"

echo "✅ Infrastructure setup complete!"
echo ""
echo "To access your cluster:"
echo "  kubectl get nodes"
echo ""
echo "To deploy agents and tools:"
echo "  kubectl apply -f $REPO_ROOT/kubernetes/overlays/$ENV/"
echo ""
echo "For local development:"
echo "  cd $REPO_ROOT"
echo "  docker-compose up -d"
