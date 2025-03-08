#!/bin/bash

# DigitalOcean Deployment Script
# This script helps deploy the application to DigitalOcean with Docker Hub integration
# Supports GitHub Actions CI/CD pipeline

set -e

# Print colored status messages
function print_status() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

function print_success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

function print_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1"
}

# Load environment variables
if [ -f "$(dirname "$0")/../../.env" ]; then
    source "$(dirname "$0")/../../.env"
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$DIGITAL_OCEAN_TOKEN" ]; then
    print_error "DigitalOcean API token not set in .env file"
    exit 1
fi

if [ -z "$DOCKER_HUB_TOKEN" ]; then
    print_error "Docker Hub token not set in .env file"
    print_error "This is required for automated deployments"
    exit 1
fi

# Set API base URL
DO_API_URL="https://api.digitalocean.com/v2"

# Function to get droplets
get_droplets() {
    print_status "Getting droplets..."
    curl -s -X GET "$DO_API_URL/droplets" \
        -H "Authorization: Bearer $DIGITAL_OCEAN_TOKEN" \
        -H "Content-Type: application/json"
}

# Function to create a new droplet
create_droplet() {
    local name=${1:-"mywebclass-automated"}
    local region=${2:-"nyc1"}
    local size=${3:-"s-1vcpu-512mb-10gb"}
    local image=${4:-"ubuntu-22-04-x64"}
    local repo=${5:-"git@github.com:kaw393939/agent_forge.git"}
    local branch=${6:-"main"}
    
    print_status "Creating new droplet '$name' with repository '$repo' (branch: $branch)..."
    
    curl -s -X POST "$DO_API_URL/droplets" \
        -H "Authorization: Bearer $DIGITAL_OCEAN_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{
            "name": "'"$name"'",
            "region": "'"$region"'",
            "size": "'"$size"'",
            "image": "'"$image"'",
            "ssh_keys": null,
            "backups": false,
            "ipv6": false,
            "user_data": "#!/bin/bash\n
                # Install Docker and Docker Compose\n
                apt-get update\n
                apt-get install -y apt-transport-https ca-certificates curl software-properties-common\n
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -\n
                add-apt-repository \"deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\"\n
                apt-get update\n
                apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin git\n
                
                # Clone repository\n
                mkdir -p /opt/mywebclass\n
                cd /opt/mywebclass\n
                git clone $repo .\n
                git checkout $branch\n
                
                # Create .env file with all environment variables\n
                echo \"OPENAI_API_KEY=$OPENAI_API_KEY\" > .env\n
                echo \"ANTHROPIC=$ANTHROPIC\" >> .env\n
                echo \"GODADDY_API_KEY=$GODADDY_API_KEY\" >> .env\n
                echo \"GODADDY_API_SECRET=$GODADDY_API_SECRET\" >> .env\n
                echo \"GODADDY_TLD=$GODADDY_TLD\" >> .env\n
                echo \"GODADDY_DOMAIN=$GODADDY_DOMAIN\" >> .env\n
                echo \"DIGITAL_OCEAN_TOKEN=$DIGITAL_OCEAN_TOKEN\" >> .env\n
                echo \"DOCKER_HUB_TOKEN=$DOCKER_HUB_TOKEN\" >> .env\n
                echo \"REGISTRY_URL=http://service-registry:8000\" >> .env\n
                
                # Set Docker Hub credentials\n
                docker login -u kaw393939 -p $DOCKER_HUB_TOKEN\n
                # Start the application\n
                docker compose pull\n
                docker compose up -d\n",
            "tags": ["mywebclass", "app"]
        }'
}

# Function to get a droplet's IP address
get_droplet_ip() {
    local droplet_id=$1
    
    print_status "Getting IP address for droplet $droplet_id..."
    
    curl -s -X GET "$DO_API_URL/droplets/$droplet_id" \
        -H "Authorization: Bearer $DIGITAL_OCEAN_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address'
}

# Function to deploy application to an existing droplet
deploy_to_droplet() {
    local droplet_id=$1
    local ssh_key=${2:-"~/.ssh/id_rsa"}
    
    print_status "Deploying application to droplet $droplet_id using SSH key: $ssh_key..."
    
    # Get the droplet's IP address
    local ip_address=$(get_droplet_ip "$droplet_id")
    
    if [ -z "$ip_address" ]; then
        print_error "Could not get IP address for droplet $droplet_id"
        exit 1
    fi
    
    print_status "Droplet IP address: $ip_address"
    
    # Wait a bit for SSH to be available
    print_status "Waiting for SSH to be available..."
    for i in {1..6}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i "$ssh_key" root@"$ip_address" echo "SSH connection successful" &>/dev/null; then
            print_success "SSH connection established"
            break
        else
            print_status "Attempt $i: Waiting for SSH server to be ready..."
            if [ $i -eq 6 ]; then
                print_error "Could not establish SSH connection after multiple attempts"
                print_status "The server might still be initializing. Try again in a few minutes."
                exit 1
            fi
            sleep 10
        fi
    done
    
    # Deploy via SSH
    print_status "Connecting to droplet via SSH to deploy application..."
    ssh -o StrictHostKeyChecking=no -i "$ssh_key" root@"$ip_address" << EOF
        # Update code repository
        cd /opt/mywebclass
        git pull
        
        # Login to Docker Hub
        docker login -u kaw393939 -p "${DOCKER_HUB_TOKEN}"
        
        # Update all environment variables in the .env file
        cat > .env << ENVEOF
OPENAI_API_KEY=${OPENAI_API_KEY}
ANTHROPIC=${ANTHROPIC}
GODADDY_API_KEY=${GODADDY_API_KEY}
GODADDY_API_SECRET=${GODADDY_API_SECRET}
GODADDY_TLD=${GODADDY_TLD}
GODADDY_DOMAIN=${GODADDY_DOMAIN}
DIGITAL_OCEAN_TOKEN=${DIGITAL_OCEAN_TOKEN}
DOCKER_HUB_TOKEN=${DOCKER_HUB_TOKEN}
REGISTRY_URL=http://service-registry:8000
ENVEOF
        
        # Update containers
        docker compose pull
        docker compose up -d
        
        echo "Application updated successfully!"
EOF
    
    if [ $? -eq 0 ]; then
        print_success "Application deployment via SSH completed successfully!"
    else
        print_error "Application deployment via SSH failed"
        exit 1
    fi
    
    # Setup DNS records pointing to this IP
    print_status "Setting up DNS records..."
    if ../domain/godaddy_manager.sh setup "$ip_address"; then
        print_success "DNS records updated successfully"
    else
        print_error "DNS record update failed, but application deployment was successful"
        print_status "You may need to manually update your DNS records"
    fi
    
    print_success "DEPLOYMENT COMPLETED SUCCESSFULLY"
    print_success "Your application should now be accessible at:"
    echo "  - http://mywebclass.org"
    echo "  - http://www.mywebclass.org"
    echo "  - http://registry.mywebclass.org"
    echo "  - http://agent.mywebclass.org"
    echo "  - http://tools.mywebclass.org"
    echo "  - http://traefik.mywebclass.org (Dashboard)"
    
    print_status "Note: DNS changes may take some time to propagate globally"
}

# Parse command line arguments
case "$1" in
    list)
        get_droplets
        ;;
    create)
        create_droplet "${2:-mywebclass-automated}" "${3:-nyc1}" "${4:-s-1vcpu-512mb-10gb}" "${5:-ubuntu-22-04-x64}" "${6:-git@github.com:kaw393939/agent_forge.git}" "${7:-main}"
        ;;
    ip)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 ip <droplet_id>"
            exit 1
        fi
        get_droplet_ip "$2"
        ;;
    deploy)
        if [ $# -lt 2 ]; then
            echo "Usage: $0 deploy <droplet_id> [ssh_key_path]"
            exit 1
        fi
        deploy_to_droplet "$2" "${3:-~/.ssh/id_rsa}"
        ;;
    *)
        echo "Usage: $0 {list|create|ip|deploy}"
        echo ""
        echo "  list                     List all droplets"
        echo "  create [name] [region] [size] [image] [repo] [branch]   Create a new droplet (defaults to mywebclass-automated, nyc1, s-1vcpu-512mb-10gb, ubuntu-22-04-x64, git@github.com:kaw393939/agent_forge.git, main)"
        echo "  ip <droplet_id>          Get a droplet's IP address"
        echo "  deploy <droplet_id> [ssh_key_path]    Deploy application to a droplet (optional ssh key path)"
        exit 1
        ;;
esac

exit 0
