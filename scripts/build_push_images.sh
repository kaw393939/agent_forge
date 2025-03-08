#!/bin/bash

# Build and Push Docker Images Script
# This script builds and pushes Docker images to Docker Hub

set -e

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

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Set paths for project directories
SERVICE_REGISTRY_DIR="$PROJECT_ROOT/service-registry"
EXAMPLE_AGENT_DIR="$PROJECT_ROOT/agents/example-agent"
EXAMPLE_TOOL_DIR="$PROJECT_ROOT/tools/example-tool"
STREAMLIT_DIR="$PROJECT_ROOT/frontend/streamlit"

# Parse command line arguments
SKIP_PUSH=false
LOCAL_BUILD_ONLY=false
FORCE_BUILD=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-push)
      SKIP_PUSH=true
      shift
      ;;
    --local-only)
      LOCAL_BUILD_ONLY=true
      shift
      ;;
    --force)
      FORCE_BUILD=true
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  --skip-push      Build images but don't push to Docker Hub"
      echo "  --local-only     Build for local use only (don't login to Docker Hub)"
      echo "  --force          Force rebuild even if image exists"
      echo "  --help           Show this help message"
      exit 0
      ;;
    *)
      print_error "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    print_status "Loaded environment variables from $PROJECT_ROOT/.env"
else
    print_warning "No .env file found. Creating one with default values..."
    touch "$PROJECT_ROOT/.env"
fi

# Set Docker Hub username from env or use default
DOCKER_USERNAME=${DOCKER_HUB_USERNAME:-"kaw393939"}

# Login to Docker Hub if not building locally only
if [ "$LOCAL_BUILD_ONLY" = false ]; then
    if [ -z "$DOCKER_HUB_TOKEN" ]; then
        print_error "DOCKER_HUB_TOKEN not set in .env file"
        print_status "If you only want to build locally, use the --local-only flag"
        exit 1
    fi
    
    print_status "Logging in to Docker Hub as $DOCKER_USERNAME..."
    echo "$DOCKER_HUB_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin

    if [ $? -ne 0 ]; then
        print_error "Failed to login to Docker Hub"
        exit 1
    fi

    print_success "Logged in to Docker Hub successfully"
else
    print_status "Building for local use only, skipping Docker Hub login"
fi

# Function to build and push a single image
build_and_push_image() {
    local dir=$1
    local image_name=$2
    local full_image_name="$DOCKER_USERNAME/agent-forge-$image_name:latest"
    
    if [ ! -d "$dir" ]; then
        print_error "Directory not found at $dir"
        return 1
    fi
    
    # Check if we should skip building (if image exists and force is not set)
    if [ "$FORCE_BUILD" = false ] && docker image inspect "$full_image_name" &>/dev/null; then
        print_status "Image $full_image_name already exists, skipping build (use --force to rebuild)"
    else
        print_status "Building $image_name image..."
        cd "$dir"
        docker build -t "$full_image_name" .
        print_success "$image_name image built successfully"
    fi
    
    # Push image if not in skip-push or local-only mode
    if [ "$SKIP_PUSH" = false ] && [ "$LOCAL_BUILD_ONLY" = false ]; then
        print_status "Pushing $image_name image to Docker Hub..."
        docker push "$full_image_name"
        print_success "$image_name image pushed successfully"
    fi
}

# Build images
print_status "Building Docker images..."

# Create array of services to build
declare -A services=(
    ["$SERVICE_REGISTRY_DIR"]="service-registry"
    ["$EXAMPLE_AGENT_DIR"]="example-agent"
    ["$EXAMPLE_TOOL_DIR"]="example-tool"
    ["$STREAMLIT_DIR"]="streamlit"
)

# Track failures
failures=0

# Build each service
for dir in "${!services[@]}"; do
    if ! build_and_push_image "$dir" "${services[$dir]}"; then
        ((failures++))
    fi
done

# Exit with error if any builds failed
if [ $failures -gt 0 ]; then
    print_error "$failures build(s) failed"
    exit 1
fi

# Tag and push versioned images if not in skip-push or local-only mode
if [ "$SKIP_PUSH" = false ] && [ "$LOCAL_BUILD_ONLY" = false ]; then
    # Generate version tag (date-time stamp)
    VERSION=$(date +"%Y%m%d%H%M")
    
    print_status "Tagging images with version: $VERSION..."
    
    # Tag versioned images
    for service_name in "${services[@]}"; do
        docker tag "$DOCKER_USERNAME/agent-forge-$service_name:latest" "$DOCKER_USERNAME/agent-forge-$service_name:$VERSION"
        print_status "Pushing $service_name:$VERSION to Docker Hub..."
        docker push "$DOCKER_USERNAME/agent-forge-$service_name:$VERSION"
    done
    
    print_success "All Docker images have been built and pushed to Docker Hub with latest and $VERSION tags!"
else
    if [ "$SKIP_PUSH" = true ]; then
        print_status "Skipped pushing images to Docker Hub (--skip-push flag was set)"
    fi
    if [ "$LOCAL_BUILD_ONLY" = true ]; then
        print_status "Built images for local use only (--local-only flag was set)"
    fi
    print_success "All Docker images have been built successfully!"
fi

# Show next steps based on context
if [ "$LOCAL_BUILD_ONLY" = false ]; then
    print_status "You can now update your Kubernetes deployment to use these images."
    print_status "After deployment, your Kubernetes services will be available at:"
    print_status "- Main: https://mywebclass.org and https://www.mywebclass.org"
    print_status "- Service Registry: https://registry.mywebclass.org"
    print_status "- Example Agent: https://agent.mywebclass.org"
    print_status "- Example Tool: https://tools.mywebclass.org"
    print_status "- Linkerd Dashboard: https://linkerd.mywebclass.org"
else
    print_status "You can now start the application locally using:"
    print_status "  cd $PROJECT_ROOT && docker-compose up -d"
fi
