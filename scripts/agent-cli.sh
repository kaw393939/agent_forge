#!/bin/bash
set -e

# Agent Framework CLI
# Provides commands for installing, configuring, and testing agent infrastructure

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Load configuration if exists
CONFIG_FILE="$REPO_ROOT/.agent-cli.conf"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check for required tools
check_dependencies() {
    local missing_deps=0
    
    echo "Checking dependencies..."
    
    # Check for terraform
    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform not found. Please install terraform."
        missing_deps=1
    else
        echo "✅ Terraform $(terraform version | head -n1 | cut -d ' ' -f 2)"
    fi
    
    # Check for doctl (DigitalOcean CLI)
    if ! command -v doctl &> /dev/null; then
        echo "❌ DigitalOcean CLI (doctl) not found. Please install doctl."
        missing_deps=1
    else
        echo "✅ doctl $(doctl version | head -n1)"
    fi
    
    # Check for kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install kubectl."
        missing_deps=1
    else
        echo "✅ kubectl $(kubectl version --client | grep -oP '(?<=GitVersion:")[^"]*')"
    fi
    
    # Check for docker
    if ! command -v docker &> /dev/null; then
        echo "❌ Docker not found. Please install docker."
        missing_deps=1
    else
        echo "✅ Docker $(docker --version | cut -d ' ' -f 3 | tr -d ',')"
    fi
    
    if [ $missing_deps -ne 0 ]; then
        echo -e "\n❌ Missing dependencies. Please install the required tools."
        exit 1
    fi
    
    echo -e "\n✅ All dependencies satisfied."
}

# Show help message
show_help() {
    echo "Agent Framework CLI"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  install                Install the agent framework infrastructure"
    echo "  domain                 Configure domain settings"
    echo "  test                   Run tests to verify the setup"
    echo "  status                 Check status of the infrastructure"
    echo "  destroy                Tear down the infrastructure"
    echo "  help                   Show this help message"
    echo ""
    echo "Use '$0 [command] --help' for more information about a command."
}

# Handle installation
run_install() {
    if [ "$1" == "--help" ]; then
        echo "Usage: $0 install [options]"
        echo ""
        echo "Options:"
        echo "  --provider=<provider>      Cloud provider (default: digitalocean)"
        echo "  --env=<environment>        Environment to deploy (default: dev)"
        echo "  --region=<region>          Region to deploy to"
        echo "  --name=<name>              Name prefix for resources"
        echo "  --token=<token>            API token for the provider"
        echo "  --nodes=<min,max>          Node count range (min,max)"
        echo "  --yes                      Skip confirmation"
        echo ""
        return
    fi
    
    # Default values
    PROVIDER=${PROVIDER:-"digitalocean"}
    ENV=${ENV:-"dev"}
    NAME_PREFIX=${NAME_PREFIX:-"agent-framework"}
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
            --env=*)
            ENV="${arg#*=}"
            shift
            ;;
            --region=*)
            REGION="${arg#*=}"
            shift
            ;;
            --name=*)
            NAME_PREFIX="${arg#*=}"
            shift
            ;;
            --token=*)
            TOKEN="${arg#*=}"
            shift
            ;;
            --nodes=*)
            NODES="${arg#*=}"
            IFS=',' read -ra NODE_ARRAY <<< "$NODES"
            MIN_NODES=${NODE_ARRAY[0]}
            MAX_NODES=${NODE_ARRAY[1]}
            shift
            ;;
            --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        esac
    done
    
    # Validate provider
    if [[ "$PROVIDER" != "digitalocean" && "$PROVIDER" != "aws" && "$PROVIDER" != "gcp" && "$PROVIDER" != "azure" ]]; then
        echo "❌ Unsupported provider: $PROVIDER"
        echo "Supported providers: digitalocean, aws, gcp, azure"
        exit 1
    fi
    
    # For now, we're implementing only DigitalOcean
    if [[ "$PROVIDER" != "digitalocean" ]]; then
        echo "⚠️ Only DigitalOcean is currently implemented. Switching to digitalocean."
        PROVIDER="digitalocean"
    fi
    
    # Check for token
    if [ -z "$TOKEN" ]; then
        echo "❌ API token is required."
        echo "Use --token=<token> to provide your DigitalOcean API token"
        exit 1
    fi
    
    # Confirm settings
    echo "Installation Settings:"
    echo "  Provider:      $PROVIDER"
    echo "  Environment:   $ENV"
    echo "  Name Prefix:   $NAME_PREFIX"
    if [ ! -z "$REGION" ]; then
        echo "  Region:        $REGION"
    fi
    if [ ! -z "$MIN_NODES" ] && [ ! -z "$MAX_NODES" ]; then
        echo "  Node Range:    $MIN_NODES-$MAX_NODES"
    fi
    
    # Ask for confirmation unless --yes is provided
    if [ "$SKIP_CONFIRM" != true ]; then
        read -p "Continue with these settings? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
    fi
    
    echo "Starting installation..."
    
    # Run the appropriate install script
    bash "$SCRIPT_DIR/install/$PROVIDER-install.sh" \
        --token="$TOKEN" \
        --env="$ENV" \
        --name="$NAME_PREFIX" \
        ${REGION:+--region="$REGION"} \
        ${MIN_NODES:+--min-nodes="$MIN_NODES"} \
        ${MAX_NODES:+--max-nodes="$MAX_NODES"}
}

# Handle domain configuration
run_domain() {
    if [ "$1" == "--help" ]; then
        echo "Usage: $0 domain [options]"
        echo ""
        echo "Options:"
        echo "  --domain=<domain>          Domain name to configure"
        echo "  --provider=<provider>      Cloud provider (default: digitalocean)"
        echo "  --token=<token>            API token for the provider"
        echo "  --yes                      Skip confirmation"
        echo ""
        return
    fi
    
    # Default values
    PROVIDER=${PROVIDER:-"digitalocean"}
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --domain=*)
            DOMAIN="${arg#*=}"
            shift
            ;;
            --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
            --token=*)
            TOKEN="${arg#*=}"
            shift
            ;;
            --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        esac
    done
    
    # Check for domain
    if [ -z "$DOMAIN" ]; then
        echo "❌ Domain is required."
        echo "Use --domain=<domain> to provide your domain"
        exit 1
    fi
    
    # Check for token
    if [ -z "$TOKEN" ]; then
        echo "❌ API token is required."
        echo "Use --token=<token> to provide your DigitalOcean API token"
        exit 1
    fi
    
    # Confirm settings
    echo "Domain Configuration:"
    echo "  Provider:      $PROVIDER"
    echo "  Domain:        $DOMAIN"
    
    # Ask for confirmation unless --yes is provided
    if [ "$SKIP_CONFIRM" != true ]; then
        read -p "Configure domain $DOMAIN? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Domain configuration cancelled."
            exit 1
        fi
    fi
    
    echo "Configuring domain..."
    
    # Run the appropriate domain configuration script
    bash "$SCRIPT_DIR/domain/$PROVIDER-domain.sh" \
        --domain="$DOMAIN" \
        --token="$TOKEN"
}

# Handle testing
run_test() {
    if [ "$1" == "--help" ]; then
        echo "Usage: $0 test [options]"
        echo ""
        echo "Options:"
        echo "  --provider=<provider>      Cloud provider (default: digitalocean)"
        echo "  --env=<environment>        Environment to test (default: dev)"
        echo "  --verbose                  Show detailed test output"
        echo ""
        return
    fi
    
    # Default values
    PROVIDER=${PROVIDER:-"digitalocean"}
    ENV=${ENV:-"dev"}
    VERBOSE=false
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
            --env=*)
            ENV="${arg#*=}"
            shift
            ;;
            --verbose)
            VERBOSE=true
            shift
            ;;
        esac
    done
    
    echo "Running tests for $PROVIDER in $ENV environment..."
    
    # Run the appropriate test script
    bash "$SCRIPT_DIR/test/$PROVIDER-test.sh" \
        --env="$ENV" \
        ${VERBOSE:+--verbose}
}

# Check infrastructure status
run_status() {
    if [ "$1" == "--help" ]; then
        echo "Usage: $0 status [options]"
        echo ""
        echo "Options:"
        echo "  --provider=<provider>      Cloud provider (default: digitalocean)"
        echo "  --env=<environment>        Environment to check (default: dev)"
        echo ""
        return
    fi
    
    # Default values
    PROVIDER=${PROVIDER:-"digitalocean"}
    ENV=${ENV:-"dev"}
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
            --env=*)
            ENV="${arg#*=}"
            shift
            ;;
        esac
    done
    
    echo "Checking status for $PROVIDER in $ENV environment..."
    
    if [ "$PROVIDER" == "digitalocean" ]; then
        if ! command -v doctl &> /dev/null; then
            echo "❌ DigitalOcean CLI (doctl) not found. Please install doctl."
            exit 1
        fi
        
        echo "Kubernetes Clusters:"
        doctl kubernetes cluster list | grep "agent-framework-$ENV" || echo "No clusters found"
        
        CLUSTER_ID=$(doctl kubernetes cluster list --format ID,Name --no-header | grep "agent-framework-$ENV" | awk '{print $1}')
        
        if [ ! -z "$CLUSTER_ID" ]; then
            echo "Node Pools:"
            doctl kubernetes cluster node-pool list $CLUSTER_ID
            
            echo "Getting kubeconfig..."
            doctl kubernetes cluster kubeconfig save $CLUSTER_ID
            
            echo "Cluster Components:"
            kubectl get pods -A
        else
            echo "No cluster found for environment: $ENV"
        fi
    else
        echo "Status check not implemented for provider: $PROVIDER"
    fi
}

# Destroy infrastructure
run_destroy() {
    if [ "$1" == "--help" ]; then
        echo "Usage: $0 destroy [options]"
        echo ""
        echo "Options:"
        echo "  --provider=<provider>      Cloud provider (default: digitalocean)"
        echo "  --env=<environment>        Environment to destroy (default: dev)"
        echo "  --token=<token>            API token for the provider"
        echo "  --yes                      Skip confirmation"
        echo ""
        return
    fi
    
    # Default values
    PROVIDER=${PROVIDER:-"digitalocean"}
    ENV=${ENV:-"dev"}
    
    # Parse arguments
    for arg in "$@"; do
        case $arg in
            --provider=*)
            PROVIDER="${arg#*=}"
            shift
            ;;
            --env=*)
            ENV="${arg#*=}"
            shift
            ;;
            --token=*)
            TOKEN="${arg#*=}"
            shift
            ;;
            --yes)
            SKIP_CONFIRM=true
            shift
            ;;
        esac
    done
    
    # Check for token
    if [ -z "$TOKEN" ]; then
        echo "❌ API token is required."
        echo "Use --token=<token> to provide your API token"
        exit 1
    fi
    
    # Confirm destruction
    echo "⚠️ WARNING: This will destroy all resources in the $ENV environment on $PROVIDER."
    echo "This action cannot be undone."
    
    # Ask for confirmation unless --yes is provided
    if [ "$SKIP_CONFIRM" != true ]; then
        read -p "Are you sure you want to destroy the infrastructure? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Destruction cancelled."
            exit 1
        fi
        
        # Double confirm
        read -p "Are you REALLY sure? Type the environment name ($ENV) to confirm: " confirm
        if [ "$confirm" != "$ENV" ]; then
            echo "Destruction cancelled."
            exit 1
        fi
    fi
    
    echo "Destroying infrastructure..."
    
    if [ "$PROVIDER" == "digitalocean" ]; then
        cd "$REPO_ROOT/terraform/digitalocean"
        export TF_VAR_do_token="$TOKEN"
        export TF_VAR_environment="$ENV"
        
        terraform init
        terraform destroy -auto-approve
        
        echo "✅ Infrastructure destroyed."
    else
        echo "Destroy not implemented for provider: $PROVIDER"
    fi
}

# Check dependencies first
check_dependencies

# Parse command
COMMAND=$1
shift || true

case $COMMAND in
    install)
        run_install "$@"
        ;;
    domain)
        run_domain "$@"
        ;;
    test)
        run_test "$@"
        ;;
    status)
        run_status "$@"
        ;;
    destroy)
        run_destroy "$@"
        ;;
    help)
        show_help
        ;;
    *)
        echo "Unknown command: $COMMAND"
        show_help
        exit 1
        ;;
esac
