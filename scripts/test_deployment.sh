#!/bin/bash

# Test Deployment Script for Agent Forge Infrastructure
# This script destroys existing infrastructure and sets it up again to test the deployment process

# Color formatting for messages
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

function print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
function print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
function print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
function print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Display header
echo -e "\n${GREEN}==========================================================${NC}"
echo -e "${GREEN}    Agent Forge Deployment Test Script                     ${NC}"
echo -e "${GREEN}==========================================================${NC}\n"

print_warning "This script will DESTROY your existing DigitalOcean resources!"
print_warning "All data will be lost! Make sure you have backup if needed."
echo ""
read -p "Do you want to continue with destroying and recreating infrastructure? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_status "Test cancelled. No changes were made."
    exit 0
fi

# Step 1: Destroy existing infrastructure
print_status "Step 1: Destroying existing infrastructure..."
"$SCRIPT_DIR/terraform_deploy.sh" destroy

if [ $? -ne 0 ]; then
    print_error "Failed to destroy infrastructure. Please check the logs above."
    read -p "Do you want to continue anyway? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Test cancelled."
        exit 1
    fi
else
    print_success "Existing infrastructure destroyed successfully."
fi

# Step 2: Wait a bit for DigitalOcean to fully process the destruction
print_status "Step 2: Waiting for DigitalOcean to process changes (30 seconds)..."
sleep 30

# Step 3: Recreate infrastructure using the new setup
print_status "Step 3: Creating new infrastructure..."
"$SCRIPT_DIR/terraform_deploy.sh" apply

if [ $? -ne 0 ]; then
    print_error "Failed to create new infrastructure. Please check the logs above."
    exit 1
else
    print_success "New infrastructure created successfully."
fi

# Step 4: Verify deployment
print_status "Step 4: Verifying deployment..."
echo -e "\n${BLUE}Kubernetes Pods:${NC}"
kubectl get pods -n agent-forge

echo -e "\n${BLUE}Ingress Resources:${NC}"
kubectl get ingress -n agent-forge

echo -e "\n${BLUE}SSL Certificates:${NC}"
kubectl get certificates -n agent-forge

# Step 5: Final verification
echo -e "\n${GREEN}==========================================================${NC}"
print_success "Deployment test completed successfully!"
print_status "Your infrastructure has been destroyed and recreated."
print_status "Please allow 5-30 minutes for DNS changes to propagate globally."
print_status "Use kubectl commands to further verify the deployment."
echo -e "${GREEN}==========================================================${NC}\n"

exit 0
