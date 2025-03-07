#!/bin/bash
set -e

# DigitalOcean Domain Configuration Script
# Configures domains and DNS records for the agent framework

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --domain=*)
        DOMAIN="${arg#*=}"
        shift
        ;;
        --token=*)
        DO_TOKEN="${arg#*=}"
        shift
        ;;
        --env=*)
        ENV="${arg#*=}"
        shift
        ;;
    esac
done

# Default environment
ENV=${ENV:-"dev"}

# Check for required arguments
if [ -z "$DOMAIN" ]; then
    echo "❌ Domain is required."
    echo "Use --domain=<domain> to provide your domain"
    exit 1
fi

if [ -z "$DO_TOKEN" ]; then
    echo "❌ DigitalOcean API token is required."
    echo "Use --token=<token> to provide your DigitalOcean API token"
    exit 1
fi

echo "🔧 Configuring domain: $DOMAIN"

# Ensure doctl is authenticated
echo "🔑 Authenticating with DigitalOcean API..."
doctl auth init -t "$DO_TOKEN"

# Check if domain exists in DigitalOcean
if doctl compute domain get "$DOMAIN" &> /dev/null; then
    echo "✅ Domain $DOMAIN already exists in DigitalOcean"
else
    echo "🌐 Creating domain $DOMAIN in DigitalOcean..."
    doctl compute domain create "$DOMAIN"
fi

# Get Kubernetes cluster details
CLUSTERS=$(doctl kubernetes cluster list --format Name,ID,RegionSlug --no-header)
CLUSTER_ID=$(echo "$CLUSTERS" | grep "agent-framework-$ENV" | awk '{print $2}')

if [ -z "$CLUSTER_ID" ]; then
    echo "❌ No cluster found for environment: $ENV"
    echo "Please create a cluster first with the install command"
    exit 1
fi

echo "☸️ Found Kubernetes cluster with ID: $CLUSTER_ID"

# Get Kubernetes cluster load balancer IP
echo "🔍 Getting load balancer IP..."
doctl kubernetes cluster kubeconfig save "$CLUSTER_ID"

# Wait for load balancer to be assigned
echo "⏳ Waiting for load balancer to be ready..."
ATTEMPTS=0
MAX_ATTEMPTS=30
LB_IP=""

while [ -z "$LB_IP" ] && [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    ATTEMPTS=$((ATTEMPTS+1))
    echo "Attempt $ATTEMPTS/$MAX_ATTEMPTS..."
    
    # Try to get the load balancer IP from Traefik service
    LB_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [ -z "$LB_IP" ]; then
        sleep 10
    fi
done

if [ -z "$LB_IP" ]; then
    echo "❌ Failed to get load balancer IP after $MAX_ATTEMPTS attempts"
    echo "Please make sure Traefik is deployed and has a load balancer service"
    exit 1
fi

echo "✅ Found load balancer IP: $LB_IP"

# Create DNS records
echo "🌐 Creating DNS records..."

# Create A record for the domain to point to the load balancer
echo "Creating A record for $DOMAIN"
doctl compute domain records create "$DOMAIN" --record-type A --record-name @ --record-data "$LB_IP" --record-ttl 300

# Create wildcard subdomain for services
echo "Creating wildcard A record for *.$DOMAIN"
doctl compute domain records create "$DOMAIN" --record-type A --record-name "*" --record-data "$LB_IP" --record-ttl 300

# List the DNS records for verification
echo "📋 Current DNS records for $DOMAIN:"
doctl compute domain records list "$DOMAIN"

echo "✅ Domain configuration complete!"
echo ""
echo "The following DNS records have been created:"
echo "  $DOMAIN -> $LB_IP"
echo "  *.$DOMAIN -> $LB_IP"
echo ""
echo "It may take some time for DNS changes to propagate (typically 5-30 minutes)."
echo "You can verify the setup by accessing these URLs once DNS has propagated:"
echo "  http://registry.$DOMAIN - Service Registry"
echo "  http://traefik.$DOMAIN - Traefik Dashboard"
