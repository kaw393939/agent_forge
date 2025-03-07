#!/bin/bash

# DigitalOcean Deployment Script
# This script helps deploy the application to DigitalOcean

set -e

# Load environment variables
if [ -f "$(dirname "$0")/../../.env" ]; then
    source "$(dirname "$0")/../../.env"
else
    echo "Error: .env file not found"
    exit 1
fi

# Check if required environment variables are set
if [ -z "$DIGITAL_OCEAN_TOKEN" ]; then
    echo "Error: DigitalOcean API token not set in .env file"
    exit 1
fi

# Set API base URL
DO_API_URL="https://api.digitalocean.com/v2"

# Function to get droplets
get_droplets() {
    echo "Getting droplets..."
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
    
    echo "Creating new droplet '$name'..."
    
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
                git clone git@github.com:kaw393939/infrastructure.git .\n
                
                # Create .env file with all environment variables\n
                echo \"OPENAI_API_KEY=$OPENAI_API_KEY\" > .env\n
                echo \"ANTHROPIC=$ANTHROPIC\" >> .env\n
                echo \"GODADDY_API_KEY=$GODADDY_API_KEY\" >> .env\n
                echo \"GODADDY_API_SECRET=$GODADDY_API_SECRET\" >> .env\n
                echo \"GODADDY_TLD=$GODADDY_TLD\" >> .env\n
                echo \"GODADDY_DOMAIN=$GODADDY_DOMAIN\" >> .env\n
                echo \"DIGITAL_OCEAN_TOKEN=$DIGITAL_OCEAN_TOKEN\" >> .env\n
                echo \"REGISTRY_URL=http://service-registry:8000\" >> .env\n
                
                # Start the application\n
                docker compose up -d\n",
            "tags": ["mywebclass", "app"]
        }'
}

# Function to get a droplet's IP address
get_droplet_ip() {
    local droplet_id=$1
    
    echo "Getting IP address for droplet $droplet_id..."
    
    curl -s -X GET "$DO_API_URL/droplets/$droplet_id" \
        -H "Authorization: Bearer $DIGITAL_OCEAN_TOKEN" \
        -H "Content-Type: application/json" | \
        jq -r '.droplet.networks.v4[] | select(.type=="public") | .ip_address'
}

# Function to deploy application to an existing droplet
deploy_to_droplet() {
    local droplet_id=$1
    
    echo "Deploying application to droplet $droplet_id..."
    
    # Get the droplet's IP address
    local ip_address=$(get_droplet_ip "$droplet_id")
    
    echo "Droplet IP address: $ip_address"
    
    # Setup DNS records pointing to this IP
    ../domain/godaddy_manager.sh setup "$ip_address"
    
    echo "Application deployment completed!"
    echo "Your application should now be accessible at http://$GODADDY_DOMAIN"
}

# Parse command line arguments
case "$1" in
    list)
        get_droplets
        ;;
    create)
        create_droplet "${2:-mywebclass-automated}" "${3:-nyc1}" "${4:-s-1vcpu-512mb-10gb}" "${5:-ubuntu-22-04-x64}"
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
            echo "Usage: $0 deploy <droplet_id>"
            exit 1
        fi
        deploy_to_droplet "$2"
        ;;
    *)
        echo "Usage: $0 {list|create|ip|deploy}"
        echo ""
        echo "  list                     List all droplets"
        echo "  create [name] [region] [size] [image]   Create a new droplet (defaults to mywebclass-automated, nyc1, s-1vcpu-512mb-10gb, ubuntu-22-04-x64)"
        echo "  ip <droplet_id>          Get a droplet's IP address"
        echo "  deploy <droplet_id>      Deploy application to a droplet"
        exit 1
        ;;
esac

exit 0
