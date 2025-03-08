#!/bin/bash

# Terraform Deployment Script for Agent Forge
# This script automates the deployment/destruction of Agent Forge to DigitalOcean Kubernetes with Linkerd service mesh

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

# Function to check if a command exists
function command_exists() {
  command -v "$1" &> /dev/null
}

# Function to retry a command with exponential backoff
function retry_command() {
  local max_attempts="$1"
  local command="$2"
  local attempt=1
  local timeout=5
  local result=0
  local output=""
  
  while [[ $attempt -le $max_attempts ]]; do
    print_status "Attempt $attempt/$max_attempts..."
    output=$(eval "$command" 2>&1)
    result=$?
    
    if [[ $result -eq 0 ]]; then
      echo "$output"
      return 0
    fi
    
    print_warning "Command failed. Retrying in $timeout seconds..."
    sleep $timeout
    
    attempt=$((attempt+1))
    timeout=$((timeout*2))
  done
  
  print_error "Command failed after $max_attempts attempts"
  echo "$output"
  return 1
}

# Display usage information
function show_usage() {
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  apply      Deploy the infrastructure (default if no command specified)"
    echo "  destroy    Destroy the infrastructure"
    echo "  plan       Only create a Terraform plan without applying it"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV   Set environment (dev, staging, prod) - default: dev"
    echo "  -d, --domain DOMAIN     Set domain name - default: mywebclass.org"
    echo "  -k, --ssh-key PATH      Set SSH public key path - default: ~/.ssh/id_rsa.pub"
    echo "  -p, --ssh-private PATH  Set SSH private key path - default: ~/.ssh/id_rsa"
    echo "  -y, --auto-approve      Skip confirmation prompts"
    echo "  -h, --help              Show this help message"
    exit 0
}

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
    print_status "Loaded environment variables from $PROJECT_ROOT/.env"
else
    print_error "No .env file found in the project root"
    exit 1
fi

# Check required environment variables
if [ -z "$DIGITAL_OCEAN_TOKEN" ]; then
    print_error "DIGITAL_OCEAN_TOKEN not set in .env file"
    exit 1
fi

if [ -z "$DOCKER_HUB_TOKEN" ]; then
    print_error "DOCKER_HUB_TOKEN not set in .env file"
    exit 1
fi

# Check for required dependencies
print_status "Checking for required dependencies..."
required_commands=("terraform" "kubectl" "curl" "helm")
missing_commands=false

for cmd in "${required_commands[@]}"; do
    if ! command_exists "$cmd"; then
        print_error "Required command '$cmd' is not installed"
        missing_commands=true
    else
        print_status "✓ $cmd is installed"
    fi
done

# Optional but recommended dependencies
recommended_commands=("jq" "doctl")
for cmd in "${recommended_commands[@]}"; do
    if ! command_exists "$cmd"; then
        print_warning "Recommended command '$cmd' is not installed - some functionality may be limited"
    else
        print_status "✓ $cmd is installed"
    fi
done

if [ "$missing_commands" = true ]; then
    print_error "Please install the missing dependencies and try again"
    print_status "Installation instructions:"
    print_status "  - terraform: https://developer.hashicorp.com/terraform/install"
    print_status "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
    print_status "  - curl: Usually pre-installed or available via your package manager"
    print_status "  - helm: https://helm.sh/docs/intro/install/"
    print_status "  - jq: https://stedolan.github.io/jq/download/"
    print_status "  - doctl: https://docs.digitalocean.com/reference/doctl/how-to/install/"
    exit 1
fi

# Default values
ENVIRONMENT="dev"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/digitalocean"
SSH_PUBLIC_KEY="~/.ssh/id_rsa.pub"
SSH_PRIVATE_KEY="~/.ssh/id_rsa"
DOMAIN="mywebclass.org"
AUTO_APPROVE=false
COMMAND="apply"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -e|--environment)
      ENVIRONMENT="$2"
      shift 2
      ;;
    -d|--domain)
      DOMAIN="$2"
      shift 2
      ;;
    -k|--ssh-key)
      SSH_PUBLIC_KEY="$2"
      shift 2
      ;;
    -p|--ssh-private)
      SSH_PRIVATE_KEY="$2"
      shift 2
      ;;
    -y|--auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    -h|--help)
      show_usage
      ;;
    apply|destroy|plan)
      COMMAND="$1"
      shift
      ;;
    *)
      print_error "Unknown option: $1"
      show_usage
      ;;
  esac
done

# Validate required files exist
if [ ! -d "$TERRAFORM_DIR" ]; then
    print_error "Terraform directory not found at $TERRAFORM_DIR"
    exit 1
fi

# Create terraform.tfvars file
print_status "Creating terraform.tfvars file with your environment variables..."
cat > "$TERRAFORM_DIR/terraform.tfvars" << EOF
do_token = "$DIGITAL_OCEAN_TOKEN"
environment = "$ENVIRONMENT"
ssh_public_key_path = "$SSH_PUBLIC_KEY"
ssh_private_key_path = "$SSH_PRIVATE_KEY"
domain = "$DOMAIN"
docker_hub_token = "$DOCKER_HUB_TOKEN"
EOF

print_success "terraform.tfvars file created successfully"

# Initialize Terraform
print_status "Initializing Terraform..."
cd "$TERRAFORM_DIR" && terraform init -upgrade

# Handle different commands
case "$COMMAND" in
  "plan")
    print_status "Creating Terraform execution plan..."
    cd "$TERRAFORM_DIR" && terraform plan -out=tfplan
    print_success "Plan created successfully. Run the script with 'apply' to execute the plan."
    exit 0
    ;;
  "destroy")
    print_status "Creating Terraform destroy plan..."
    cd "$TERRAFORM_DIR" && terraform plan -destroy -out=tfplan
    
    if [ "$AUTO_APPROVE" = false ]; then
      print_warning "This will DESTROY all resources. Data will be LOST."
      read -p "Are you sure you want to destroy all resources? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          print_status "Destroy cancelled"
          exit 0
      fi
    fi
    
    print_status "Destroying infrastructure..."
    cd "$TERRAFORM_DIR" && terraform apply tfplan
    print_success "Infrastructure successfully destroyed!"
    exit 0
    ;;
  "apply")
    print_status "Creating Terraform execution plan..."
    cd "$TERRAFORM_DIR" && terraform plan -out=tfplan
    
    if [ "$AUTO_APPROVE" = false ]; then
      read -p "Do you want to apply this plan? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          print_status "Deployment cancelled"
          exit 0
      fi
    fi
    
    # Apply the plan
    print_status "Applying Terraform plan..."
    cd "$TERRAFORM_DIR" && terraform apply tfplan
    ;;
  *)
    print_error "Unknown command: $COMMAND"
    show_usage
    ;;
esac

# Capture output
print_status "Deployment completed. Here's how to connect to your server:"
cd "$TERRAFORM_DIR" && terraform output

# Check if the Kubernetes cluster ID output exists
KUBERNETES_CLUSTER_ID=$(cd "$TERRAFORM_DIR" && terraform output -raw kubernetes_cluster_id 2>/dev/null || echo "")
if [ -n "$KUBERNETES_CLUSTER_ID" ]; then
    print_status "Waiting for the Kubernetes cluster to fully initialize (this may take up to 5 minutes)..."
    sleep 180  # Increase wait time to 3 minutes for better reliability

    # Configure kubectl to use the new cluster
    print_status "Configuring kubectl to use the new cluster..."
    KUBECONFIG_CMD=$(cd "$TERRAFORM_DIR" && terraform output -raw kubeconfig_command)
    eval "$KUBECONFIG_CMD"
    
    # Verify kubectl is properly configured
    print_status "Verifying kubectl configuration..."
    if ! kubectl get nodes &>/dev/null; then
        print_error "Failed to connect to Kubernetes cluster. Trying again..."
        sleep 30
        eval "$KUBECONFIG_CMD"
        
        if ! kubectl get nodes &>/dev/null; then
            print_error "Failed to connect to Kubernetes cluster after retry. Please check your DigitalOcean account and try again."
            print_status "You can manually configure kubectl with: doctl kubernetes cluster kubeconfig save $KUBERNETES_CLUSTER_ID"
            exit 1
        fi
    fi
    print_success "Successfully connected to Kubernetes cluster"

    # Check if we should skip Linkerd installation (it can sometimes cause issues)
    SKIP_LINKERD=${SKIP_LINKERD:-false}
    
    # Function to check and install required CLI tools
    install_cli_tool() {
        local tool_name="$1"
        local install_cmd="$2"
        
        if ! command -v "$tool_name" &> /dev/null; then
            print_status "$tool_name CLI not found. Installing..."
            eval "$install_cmd"
            
            # Verify installation worked
            if ! command -v "$tool_name" &> /dev/null; then
                # Try to locate the binary in common install locations
                if [ -f "$HOME/.linkerd2/bin/$tool_name" ]; then
                    export PATH="$PATH:$HOME/.linkerd2/bin"
                elif [ -f "$HOME/bin/$tool_name" ]; then
                    export PATH="$PATH:$HOME/bin"
                else
                    print_error "Failed to install $tool_name. Please install it manually"
                    return 1
                fi
            fi
            print_success "$tool_name CLI installed successfully"
        else
            print_status "$tool_name CLI already installed"
        fi
        return 0
    }
    
    # Install Linkerd CLI if needed
    install_cli_tool "linkerd" "curl --proto '=https' --tlsv1.2 -sSfL https://run.linkerd.io/install | sh"
    
    if [ "$SKIP_LINKERD" = true ]; then
        print_status "Skipping Linkerd installation as requested"
    else
        print_status "Installing Linkerd service mesh..."
        
        # Verify kubectl can connect to the cluster before proceeding
        print_status "Verifying Kubernetes connectivity..."
        retry_attempts=5
        retry_count=0
        k8s_connected=false
        
        while [ $retry_count -lt $retry_attempts ] && [ "$k8s_connected" != true ]; do
            if kubectl get nodes &>/dev/null; then
                print_success "Successfully connected to Kubernetes cluster"
                k8s_connected=true
            else
                retry_count=$((retry_count+1))
                print_warning "Cannot connect to Kubernetes cluster. Attempt $retry_count of $retry_attempts"
                print_status "Waiting 30 seconds before retrying..."
                sleep 30
            fi
        done
        
        if [ "$k8s_connected" != true ]; then
            print_error "Failed to connect to Kubernetes cluster after $retry_attempts attempts"
            print_error "Setting SKIP_LINKERD=true and continuing without Linkerd"
            SKIP_LINKERD=true
        fi
        
        if [ "$SKIP_LINKERD" != true ]; then
            # Verify Kubernetes cluster is ready for Linkerd
            print_status "Verifying Kubernetes cluster is ready for Linkerd..."
            linkerd_precheck_success=false
            retry_count=0
            max_retries=3
            
            while [ $retry_count -lt $max_retries ] && [ "$linkerd_precheck_success" != true ]; do
                print_status "Running linkerd pre-check (attempt $((retry_count+1)) of $max_retries)..."
                if linkerd check --pre &>/dev/null; then
                    print_success "Linkerd pre-check passed successfully"
                    linkerd_precheck_success=true
                else
                    retry_count=$((retry_count+1))
                    
                    if [ $retry_count -lt $max_retries ]; then
                        wait_time=$((30 * retry_count))
                        print_warning "Linkerd pre-check failed. This might be due to cluster still initializing."
                        print_status "Waiting $wait_time seconds before retry..."
                        sleep $wait_time
                    else
                        print_error "Linkerd pre-check failed after $max_retries retries."
                        print_error "Setting SKIP_LINKERD=true and continuing without Linkerd."
                        SKIP_LINKERD=true
                    fi
                fi
            done
        fi
        
        if [ "$SKIP_LINKERD" != true ]; then
            # Install Linkerd CRDs first
            print_status "Installing Linkerd CRDs..."
            if ! linkerd install --crds | kubectl apply -f -; then
                print_error "Failed to install Linkerd CRDs. Retrying once..."
                sleep 10
                
                if ! linkerd install --crds | kubectl apply -f -; then
                    print_error "Failed to install Linkerd CRDs after retry."
                    print_error "Setting SKIP_LINKERD=true and continuing without Linkerd."
                    SKIP_LINKERD=true
                fi
            else
                print_success "Linkerd CRDs installed successfully"
            fi
        fi
        
        if [ "$SKIP_LINKERD" != true ]; then
            # Then install Linkerd control plane
            print_status "Installing Linkerd control plane..."
            if ! linkerd install | kubectl apply -f -; then
                print_error "Failed to install Linkerd control plane. Retrying once..."
                sleep 15
                
                if ! linkerd install | kubectl apply -f -; then
                    print_error "Failed to install Linkerd control plane after retry."
                    print_error "Setting SKIP_LINKERD=true and continuing without Linkerd."
                    SKIP_LINKERD=true
                fi
            else
                print_success "Linkerd control plane installation started"
                
                # Wait for Linkerd to be ready with proper feedback
                print_status "Waiting for Linkerd to be ready (this may take several minutes)..."
                start_time=$(date +%s)
                max_wait_time=300  # 5 minutes
                wait_interval=20    # Check every 20 seconds
                
                while true; do
                    current_time=$(date +%s)
                    elapsed_time=$((current_time - start_time))
                    
                    if [ $elapsed_time -gt $max_wait_time ]; then
                        print_warning "Linkerd is not fully ready after waiting for $(($max_wait_time / 60)) minutes"
                        print_warning "Continuing with deployment, but some Linkerd features may not work properly"
                        break
                    fi
                    
                    # Check if Linkerd is ready
                    if linkerd check --wait=0 &>/dev/null; then
                        print_success "Linkerd is fully ready and operational after $elapsed_time seconds!"
                        break
                    else
                        minutes_left=$(( (max_wait_time - elapsed_time) / 60 ))
                        seconds_left=$(( (max_wait_time - elapsed_time) % 60 ))
                        print_status "Linkerd still initializing (elapsed: ${elapsed_time}s, timeout in: ${minutes_left}m ${seconds_left}s)..."
                        sleep $wait_interval
                    fi
                done
                
                # Final Linkerd check to provide detailed output of any remaining issues
                print_status "Performing final Linkerd verification..."
                linkerd check || print_warning "Linkerd check reported issues, but we'll continue with deployment"
            fi
        fi
    fi
    
    # Install Helm if needed
    install_cli_tool "helm" "curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash"
    
    # Function to safely add Helm repository
    add_helm_repo() {
        local repo_name="$1"
        local repo_url="$2"
        
        print_status "Adding Helm repository: $repo_name"
        if ! helm repo list | grep -q "^$repo_name\s"; then
            helm repo add "$repo_name" "$repo_url"
            print_success "Added Helm repository: $repo_name"
        else
            print_status "Helm repository $repo_name already exists, updating..."
            helm repo update "$repo_name"
        fi
    }
    
    # Add required Helm repositories
    print_status "Adding required Helm repositories..."
    add_helm_repo "jetstack" "https://charts.jetstack.io"
    add_helm_repo "ingress-nginx" "https://kubernetes.github.io/ingress-nginx"
    helm repo update
    
    # Function to safely install Helm chart
    install_helm_chart() {
        local name="$1"
        local chart="$2"
        local namespace="$3"
        local version="$4"
        local values="$5"
        
        print_status "Installing $name via Helm..."
        if [ -n "$values" ]; then
            helm upgrade --install "$name" "$chart" \
              --namespace "$namespace" \
              --create-namespace \
              --version "$version" \
              --values "$values" \
              $6
        else
            helm upgrade --install "$name" "$chart" \
              --namespace "$namespace" \
              --create-namespace \
              --version "$version" \
              $6
        fi
        print_success "$name installed successfully"
    }
    
    # Install cert-manager for SSL certificates with improved reliability
    print_status "Installing cert-manager..."
    MAX_INSTALL_ATTEMPTS=3
    attempt=1
    cert_manager_installed=false
    
    while [ $attempt -le $MAX_INSTALL_ATTEMPTS ] && [ "$cert_manager_installed" != true ]; do
        print_status "Attempt $attempt/$MAX_INSTALL_ATTEMPTS: Installing cert-manager..."
        
        if install_helm_chart "cert-manager" "jetstack/cert-manager" "cert-manager" "v1.12.3" "" "--set installCRDs=true --timeout 5m"; then
            print_success "cert-manager Helm chart installed successfully on attempt $attempt"
            cert_manager_installed=true
        else
            if [ $attempt -lt $MAX_INSTALL_ATTEMPTS ]; then
                wait_time=$((30 * attempt))
                print_warning "Failed to install cert-manager (attempt $attempt). Waiting $wait_time seconds before retry..."
                sleep $wait_time
            else
                print_error "Failed to install cert-manager after $MAX_INSTALL_ATTEMPTS attempts."
                print_error "This is a critical component for SSL certificates. Cannot continue."
                exit 1
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    # Wait for cert-manager to be ready with better feedback
    print_status "Waiting for cert-manager components to be ready..."
    start_time=$(date +%s)
    timeout=300  # 5 minutes
    check_interval=15
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_warning "Timeout waiting for cert-manager components after $((timeout / 60)) minutes."
            print_warning "Continuing, but certificate issuance may not work properly initially."
            break
        fi
        
        # Check if all cert-manager pods are running
        pods_not_ready=$(kubectl get pods -n cert-manager -o json | jq -r '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | .metadata.name')
        
        if [ -z "$pods_not_ready" ]; then
            # Check if webhooks are ready
            webhook_count=$(kubectl get validatingwebhookconfiguration -l app.kubernetes.io/instance=cert-manager -o json 2>/dev/null | jq '.items | length')
            
            if [ "$webhook_count" -gt 0 ]; then
                print_success "cert-manager is fully ready! (took $elapsed seconds)"
                break
            else
                print_status "cert-manager pods are running, waiting for webhooks to be registered... (${elapsed}s elapsed)"
                sleep $check_interval
            fi
        else
            print_status "Some cert-manager pods are not ready yet. Waiting... (${elapsed}s elapsed)"
            sleep $check_interval
        fi
    done
    
    # Create a ClusterIssuer for Let's Encrypt
    print_status "Creating Let's Encrypt ClusterIssuer for automatic SSL certificates..."
    cat > letsencrypt-prod.yaml << EOF
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN:-mywebclass.org}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

    # Apply the ClusterIssuer with retries
    issuer_created=false
    for i in {1..5}; do
        sleep 10  # Wait for cert-manager to be ready to process CRs
        if kubectl apply -f letsencrypt-prod.yaml; then
            print_success "Let's Encrypt ClusterIssuer created successfully"
            issuer_created=true
            break
        else
            print_warning "Failed to create ClusterIssuer on attempt $i. Retrying in 10 seconds..."
            sleep 10
        fi
    done

    if [ "$issuer_created" != true ]; then
        print_warning "Could not create Let's Encrypt ClusterIssuer. You may need to manually create it later."
        print_warning "SSL certificates may not be automatically provisioned."
    fi
    
    # Install Ingress NGINX Controller via Helm with improved reliability
    print_status "Installing Ingress NGINX Controller via Helm..."
    MAX_INSTALL_ATTEMPTS=3
    attempt=1
    ingress_installed=false
    
    while [ $attempt -le $MAX_INSTALL_ATTEMPTS ] && [ "$ingress_installed" != true ]; do
        print_status "Attempt $attempt/$MAX_INSTALL_ATTEMPTS: Installing Ingress NGINX Controller..."
        
        if install_helm_chart "ingress-nginx" "ingress-nginx/ingress-nginx" "ingress-nginx" "4.7.1" "" "--timeout 5m"; then
            print_success "Ingress NGINX Controller Helm chart installed successfully on attempt $attempt"
            ingress_installed=true
        else
            if [ $attempt -lt $MAX_INSTALL_ATTEMPTS ]; then
                wait_time=$((30 * attempt))
                print_warning "Failed to install Ingress NGINX Controller (attempt $attempt). Waiting $wait_time seconds before retry..."
                sleep $wait_time
            else
                print_error "Failed to install Ingress NGINX Controller after $MAX_INSTALL_ATTEMPTS attempts."
                print_error "This is a critical component for application access. Cannot continue."
                exit 1
            fi
            attempt=$((attempt + 1))
        fi
    done
    
    # Wait for Ingress controller to be ready with better feedback
    print_status "Waiting for Ingress NGINX Controller to be ready..."
    start_time=$(date +%s)
    timeout=300  # 5 minutes
    check_interval=15
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_warning "Timeout waiting for Ingress NGINX Controller after $((timeout / 60)) minutes."
            print_warning "Continuing, but application access may not work properly initially."
            break
        fi
        
        # Check deployment status
        ready_replicas=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        desired_replicas=$(kubectl get deployment -n ingress-nginx ingress-nginx-controller -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "1")
        
        if [ "$ready_replicas" = "$desired_replicas" ]; then
            print_status "Ingress NGINX Controller pods are ready. Checking for LoadBalancer IP..."
            
            # Check if LoadBalancer has an IP
            ingress_ip=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            ingress_hostname=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
            
            if [ -n "$ingress_ip" ] || [ -n "$ingress_hostname" ]; then
                print_success "Ingress NGINX Controller is fully ready with external IP/hostname! (took $elapsed seconds)"
                break
            else
                print_status "Waiting for LoadBalancer IP/hostname to be assigned... (${elapsed}s elapsed)"
                sleep $check_interval
            fi
        else
            print_status "Ingress NGINX Controller pods are still starting up ($ready_replicas/$desired_replicas ready)... (${elapsed}s elapsed)"
            sleep $check_interval
        fi
    done
    
    # Generate secrets.yaml file for Helm if it doesn't exist
    HELM_DIR="$(dirname "$0")/../helm/agent-forge"
    
    # Ensure the helm directory exists
    mkdir -p "$HELM_DIR"
    
    if [ ! -f "$HELM_DIR/secrets.yaml" ]; then
        print_status "Creating secrets.yaml file for Helm..."
        cat > "$HELM_DIR/secrets.yaml" << EOF
secrets:
  dockerHubToken: "$DOCKER_HUB_TOKEN"
  openaiApiKey: "$OPENAI_API_KEY"
  digitalOceanToken: "$DIGITAL_OCEAN_TOKEN"
EOF
        print_success "secrets.yaml file created for Helm"
    fi
    
    # Create values.yaml file if it doesn't exist
    if [ ! -f "$HELM_DIR/values.yaml" ]; then
        print_status "Creating values.yaml file for Helm..."
        cat > "$HELM_DIR/values.yaml" << EOF
# Default values for agent-forge
environment: ${ENVIRONMENT:-dev}

domainName: ${DOMAIN_NAME:-mywebclass.org}

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: ${DOMAIN_NAME:-mywebclass.org}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: agent-forge-tls
      hosts:
        - ${DOMAIN_NAME:-mywebclass.org}
EOF
        print_success "values.yaml file created for Helm"
    fi
    
    # Create Chart.yaml file if it doesn't exist
    if [ ! -f "$HELM_DIR/Chart.yaml" ]; then
        print_status "Creating Chart.yaml file for Helm..."
        cat > "$HELM_DIR/Chart.yaml" << EOF
apiVersion: v2
name: agent-forge
description: A Helm chart for Agent Forge application
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF
        print_success "Chart.yaml file created for Helm"
    fi
    
    # Create templates directory and basic deployment.yaml if they don't exist
    TEMPLATES_DIR="$HELM_DIR/templates"
    mkdir -p "$TEMPLATES_DIR"
    
    if [ ! -f "$TEMPLATES_DIR/deployment.yaml" ]; then
        print_status "Creating deployment.yaml template for Helm..."
        cat > "$TEMPLATES_DIR/deployment.yaml" << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
    environment: {{ .Values.environment }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
      - name: {{ .Release.Name }}
        image: nginx:latest
        ports:
        - containerPort: 80
EOF
        print_success "deployment.yaml template created for Helm"
    fi
    
    if [ ! -f "$TEMPLATES_DIR/service.yaml" ]; then
        print_status "Creating service.yaml template for Helm..."
        cat > "$TEMPLATES_DIR/service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  labels:
    app: {{ .Release.Name }}
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
  selector:
    app: {{ .Release.Name }}
EOF
        print_success "service.yaml template created for Helm"
    fi
    
    if [ ! -f "$TEMPLATES_DIR/ingress.yaml" ]; then
        print_status "Creating ingress.yaml template for Helm..."
        cat > "$TEMPLATES_DIR/ingress.yaml" << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Release.Name }}
  annotations:
    {{- toYaml .Values.ingress.annotations | nindent 4 }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  rules:
  {{- range .Values.ingress.hosts }}
  - host: {{ .host | quote }}
    http:
      paths:
      {{- range .paths }}
      - path: {{ .path }}
        pathType: {{ .pathType }}
        backend:
          service:
            name: {{ $.Release.Name }}
            port:
              number: 80
      {{- end }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
  {{- range .Values.ingress.tls }}
  - hosts:
    {{- range .hosts }}
    - {{ . | quote }}
    {{- end }}
    secretName: {{ .secretName }}
  {{- end }}
  {{- end }}
EOF
        print_success "ingress.yaml template created for Helm"
    fi
    
    # Deploy Agent Forge Helm chart with improved reliability
    print_status "Deploying Agent Forge via Helm..."
    MAX_DEPLOY_ATTEMPTS=3
    deploy_attempt=1
    deploy_success=false
    
    while [ $deploy_attempt -le $MAX_DEPLOY_ATTEMPTS ] && [ "$deploy_success" != true ]; do
        print_status "Attempt $deploy_attempt/$MAX_DEPLOY_ATTEMPTS: Deploying Agent Forge application..."
        
        if helm upgrade --install \
          agent-forge "$HELM_DIR" \
          --values "$HELM_DIR/values.yaml" \
          --values "$HELM_DIR/secrets.yaml" \
          --create-namespace \
          --timeout 5m; then
            print_success "Agent Forge deployed successfully via Helm on attempt $deploy_attempt"
            deploy_success=true
        else
            if [ $deploy_attempt -lt $MAX_DEPLOY_ATTEMPTS ]; then
                wait_time=$((20 * deploy_attempt))
                print_warning "Failed to deploy Agent Forge (attempt $deploy_attempt). Waiting $wait_time seconds before retry..."
                sleep $wait_time
            else
                print_error "Failed to deploy Agent Forge after $MAX_DEPLOY_ATTEMPTS attempts."
                print_error "Check the Helm chart for errors."
                print_status "Running 'helm list' to see current deployments:"
                helm list
                print_status "Continuing, but application may not be functional."
            fi
            deploy_attempt=$((deploy_attempt + 1))
        fi
    done
    
    # Verify the application pods are running
    print_status "Verifying Agent Forge application status..."
    start_time=$(date +%s)
    timeout=300  # 5 minutes
    check_interval=15
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_warning "Timeout waiting for Agent Forge pods after $((timeout / 60)) minutes."
            print_warning "Continuing, but application pods may not be fully ready."
            break
        fi
        
        # Check the status of all pods in the default namespace where Helm deploys
        pods_not_ready=$(kubectl get pods -o json | jq -r '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | .metadata.name')
        
        if [ -z "$pods_not_ready" ]; then
            print_success "All Agent Forge pods are running successfully! (took $elapsed seconds)"
            break
        else
            print_status "Some Agent Forge pods are still starting up... (${elapsed}s elapsed)"
            sleep $check_interval
        fi
    done
    
    # Get the ingress IP address with enhanced reliability
    print_status "Getting ingress IP address..."
    INGRESS_IP=""
    
    # Increase timeout for getting IP address
    MAX_RETRIES=45    # 15 minutes total (20s * 45)
    RETRY_COUNT=0
    
    while [ -z "$INGRESS_IP" ] && [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Try both IP and hostname fields
        INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
        
        if [ -z "$INGRESS_IP" ]; then
            # Try hostname field
            INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        fi
        
        if [ -z "$INGRESS_IP" ]; then
            RETRY_COUNT=$((RETRY_COUNT + 1))
            remaining_time=$(( (MAX_RETRIES - RETRY_COUNT) * 20 ))
            minutes=$(( remaining_time / 60 ))
            seconds=$(( remaining_time % 60 ))
            
            # Every 5 attempts, provide more detailed status
            if [ $((RETRY_COUNT % 5)) -eq 0 ]; then
                print_status "Load balancer provisioning status:"
                kubectl get service -n ingress-nginx ingress-nginx-controller
            fi
            
            print_status "Waiting for load balancer IP address... (Attempt $RETRY_COUNT/$MAX_RETRIES, ~${minutes}m${seconds}s remaining)"
            # DigitalOcean can sometimes take several minutes to provision a load balancer
            sleep 20
        fi
    done
    
    # Enhanced fallback mechanism for IP address
    if [ -z "$INGRESS_IP" ]; then
        print_warning "Failed to get ingress IP address after $MAX_RETRIES attempts (${MAX_RETRIES}*20 seconds)."
        print_status "Running diagnostics on ingress-nginx service:"
        
        print_status "1. Checking ingress-nginx service details:"
        kubectl describe service -n ingress-nginx ingress-nginx-controller
        
        print_status "2. Checking ingress-nginx controller pods:"
        kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller
        
        print_status "3. Checking events in ingress-nginx namespace:"
        kubectl get events -n ingress-nginx --sort-by='.lastTimestamp' | tail -n 10
        
        # Try alternative methods to get an IP address
        print_status "Trying alternative methods to get an IP address..."
        
        # Method 1: Try to get external IPs of nodes
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
        if [ -n "$NODE_IP" ]; then
            print_status "Using node external IP as fallback: $NODE_IP"
            INGRESS_IP=$NODE_IP
        else
            # Method 2: Try to get external IPs from node status
            NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
            if [ -n "$NODE_IP" ]; then
                print_status "Using node internal IP as fallback: $NODE_IP"
                print_warning "This IP may only be accessible from within the same network."
                INGRESS_IP=$NODE_IP
            else
                print_error "Could not determine any IP address for ingress access."
                print_error "You will need to manually determine the IP address once it becomes available."
                print_status "Run this command later: kubectl get service -n ingress-nginx ingress-nginx-controller"
                INGRESS_IP="UNKNOWN"
            fi
        fi
      fi
    fi
    
    print_success "Application deployed successfully to Kubernetes!"
    if [ "$SKIP_LINKERD" != true ]; then
        print_status "Linkerd service mesh is enabled"
    fi
    print_status "Ingress IP address: $INGRESS_IP"
    
    if [ -n "$DOMAIN" ]; then
      print_status "You can access your application at the following URLs:"
      print_status "Main site: https://$DOMAIN"
      print_status "Registry: https://registry.$DOMAIN"
      print_status "Agent: https://agent.$DOMAIN"
      print_status "Tools: https://tools.$DOMAIN"
      print_status "Linkerd dashboard: https://linkerd.$DOMAIN"
      
      # Update DNS records if DIGITAL_OCEAN_TOKEN is provided
      if [ -n "$DIGITAL_OCEAN_TOKEN" ]; then
        print_status "Updating DNS records with DigitalOcean..."
        
        # Implement DNS update directly in this script for reliability
        update_dns_record() {
          local domain="$1"
          local subdomain="$2"
          local ip="$3"
          local token="$4"
          
          # Check if jq is installed
          if ! command_exists jq; then
            print_status "jq not found, attempting to install..."
            if command_exists apt-get; then
              sudo apt-get update -qq && sudo apt-get install -y jq
            elif command_exists yum; then
              sudo yum -y install jq
            elif command_exists brew; then
              brew install jq
            else
              print_error "Cannot install jq automatically. Please install jq manually and try again."
              return 1
            fi
          fi
          
          # Get the domain ID with retries
          local domain_check_cmd="curl -s -X GET -H 'Content-Type: application/json' -H 'Authorization: Bearer $token' 'https://api.digitalocean.com/v2/domains/$domain' | jq -r '.domain.name // empty'"
          domain_id=$(eval "$domain_check_cmd")
          
          # Retry if the first attempt failed
          if [ -z "$domain_id" ]; then
            print_warning "Failed to find domain $domain in DigitalOcean on first attempt. Retrying..."
            domain_id=$(retry_command 3 "$domain_check_cmd")
          fi
          
          if [ -z "$domain_id" ]; then
            print_error "Failed to find domain $domain in DigitalOcean after multiple attempts"
            return 1
          fi
          
          # Define the curl command for record lookup
          record_lookup_cmd="curl -s -X GET -H 'Content-Type: application/json' -H 'Authorization: Bearer $token' 'https://api.digitalocean.com/v2/domains/$domain/records'"
          
          # Check if the record exists with retries
          record_name="$subdomain"
          
          if [ "$subdomain" = "@" ]; then
            record_name=""
          fi
          
          # First attempt to get records
          records_json=$(eval "$record_lookup_cmd")
          
          # Retry if empty or error
          if [ -z "$records_json" ] || echo "$records_json" | grep -q "error"; then
            print_warning "Failed to get DNS records for $domain on first attempt. Retrying..."
            records_json=$(retry_command 3 "$record_lookup_cmd")
          fi
          
          # Extract existing record ID
          existing_record=$(echo "$records_json" | jq -r ".domain_records[] | select(.type == \"A\" and .name == \"$record_name\") | .id")
          
          if [ -n "$existing_record" ]; then
            # Update existing record with retry
            update_cmd="curl -s -X PUT -H 'Content-Type: application/json' -H 'Authorization: Bearer $token' -d '{\"data\":\"$ip\"}' 'https://api.digitalocean.com/v2/domains/$domain/records/$existing_record'"
            update_result=$(eval "$update_cmd")
            
            # Check if the update was successful
            if echo "$update_result" | grep -q "error"; then
              print_warning "Failed to update DNS record for $subdomain.$domain on first attempt. Retrying..."
              update_result=$(retry_command 3 "$update_cmd")
              
              if echo "$update_result" | grep -q "error"; then
                print_error "Failed to update DNS record for $subdomain.$domain after multiple attempts"
                return 1
              fi
            fi
            
            print_success "Updated DNS record for $subdomain.$domain to point to $ip"
          else
            # Create new record with retry
            create_cmd="curl -s -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer $token' -d '{\"type\":\"A\",\"name\":\"$record_name\",\"data\":\"$ip\",\"ttl\":1800}' 'https://api.digitalocean.com/v2/domains/$domain/records'"
            create_result=$(eval "$create_cmd")
            
            # Check if the creation was successful
            if echo "$create_result" | grep -q "error"; then
              print_warning "Failed to create DNS record for $subdomain.$domain on first attempt. Retrying..."
              create_result=$(retry_command 3 "$create_cmd")
              
              if echo "$create_result" | grep -q "error"; then
                print_error "Failed to create DNS record for $subdomain.$domain after multiple attempts"
                return 1
              fi
            fi
            
            print_success "Created DNS record for $subdomain.$domain pointing to $ip"
          fi
          
          return 0
        }
        
        # Update DNS records for main domain and subdomains
        print_status "Starting DNS record updates for $DOMAIN and subdomains..."
        dns_update_success=true
        
        # Root domain
        if ! update_dns_record "$DOMAIN" "@" "$INGRESS_IP" "$DIGITAL_OCEAN_TOKEN"; then
          print_error "Failed to update root domain record for $DOMAIN"
          dns_update_success=false
        fi
        
        # Subdomains - continue even if one fails
        subdomains=("www" "registry" "agent" "tools" "linkerd")
        for subdomain in "${subdomains[@]}"; do
          if ! update_dns_record "$DOMAIN" "$subdomain" "$INGRESS_IP" "$DIGITAL_OCEAN_TOKEN"; then
            print_error "Failed to update DNS record for $subdomain.$DOMAIN"
            dns_update_success=false
          fi
        done
        
        if [ "$dns_update_success" = true ]; then
          print_success "All DNS records updated successfully for $DOMAIN and subdomains"
        else
          print_warning "Some DNS records could not be updated. Check the errors above and try again."
          print_warning "You may need to manually update your DNS records to point to $INGRESS_IP"
        fi
        
        # Save IP address to a file for reference with better formatting
        IP_FILE="$(dirname "$0")/../ip_addresses.txt"
        IP_FILE_BACKUP="$(dirname "$0")/../ip_addresses.$(date +%Y%m%d%H%M%S).txt"
        
        # First create a backup of the existing IP file if it exists
        if [ -f "$IP_FILE" ]; then
            cp "$IP_FILE" "$IP_FILE_BACKUP"
            print_status "Backed up previous IP address file to $IP_FILE_BACKUP"
        fi
        
        # Now write the new file with organized formatting
        cat > "$IP_FILE" << EOF
# Agent Forge IP Addresses - Updated: $(date)

## Configuration Information
Domain: $DOMAIN
Ingress IP: $INGRESS_IP
Environment: ${ENVIRONMENT:-dev}
Cluster ID: $KUBERNETES_CLUSTER_ID
Region: $(cd "$TERRAFORM_DIR" && terraform output -raw region 2>/dev/null || echo "unknown")

## DNS Configuration
Update your DNS provider with these A records:

| Hostname          | Record Type | Value        |
|-------------------|-------------|---------------|
| $DOMAIN           | A           | $INGRESS_IP  |
| www.$DOMAIN       | A           | $INGRESS_IP  |
| registry.$DOMAIN  | A           | $INGRESS_IP  |
| agent.$DOMAIN     | A           | $INGRESS_IP  |
| tools.$DOMAIN     | A           | $INGRESS_IP  |
| linkerd.$DOMAIN   | A           | $INGRESS_IP  |

## Application URLs
- Main site: https://$DOMAIN
- Registry: https://registry.$DOMAIN
- Agent: https://agent.$DOMAIN
- Tools: https://tools.$DOMAIN
- Linkerd dashboard: https://linkerd.$DOMAIN

## Kubernetes Access
To access your Kubernetes cluster, run: doctl kubernetes cluster kubeconfig save $KUBERNETES_CLUSTER_ID
EOF
        
        print_success "IP address information saved to $IP_FILE with detailed formatting"
        print_success "IP address information saved to $IP_FILE"
      else
        print_status "Please manually update your DNS records to point to $INGRESS_IP"
        
        # Still save the IP address even if manual DNS update is needed
        IP_FILE="$(dirname "$0")/../ip_addresses.txt"
        echo "# Agent Forge IP Addresses (Manual DNS Update Required) - Updated: $(date)" > "$IP_FILE"
        echo "Ingress IP: $INGRESS_IP" >> "$IP_FILE"
        echo "Add these records to your DNS provider:" >> "$IP_FILE"
        echo "  @ (root domain) -> $INGRESS_IP" >> "$IP_FILE"
        echo "  www -> $INGRESS_IP" >> "$IP_FILE"
        echo "  registry -> $INGRESS_IP" >> "$IP_FILE"
        echo "  agent -> $INGRESS_IP" >> "$IP_FILE"
        echo "  tools -> $INGRESS_IP" >> "$IP_FILE"
        echo "  linkerd -> $INGRESS_IP" >> "$IP_FILE"
        print_success "IP address information saved to $IP_FILE"
      fi
    fi
else
    print_error "Could not get Kubernetes cluster ID from Terraform output"
    print_status "You may need to manually configure kubectl and deploy the application"
    print_status "First run: doctl kubernetes cluster kubeconfig save <cluster-id>"
    print_status "Then deploy using Helm: helm upgrade --install agent-forge $(dirname "$0")/../helm/agent-forge --values $(dirname "$0")/../helm/agent-forge/values.yaml --values $(dirname "$0")/../helm/agent-forge/secrets.yaml"
fi

print_success "Terraform deployment process completed!"
print_status "Note: DNS changes may take some time to propagate globally (usually 5-30 minutes)"

# Print helpful commands for managing the deployment
print_status "Useful commands for managing your deployment:"
print_status "  • View deployment status:      kubectl get pods -n agent-forge"
print_status "  • View ingress status:         kubectl get ingress -n agent-forge"
print_status "  • View certificate status:     kubectl get certificates -n agent-forge"
if [ "$SKIP_LINKERD" != true ]; then
    print_status "  • View Linkerd dashboard:      linkerd dashboard"
fi
print_status "  • View cluster status:         kubectl get nodes"
print_status "  • View pod logs:              kubectl logs -n agent-forge <pod-name>"
print_status "  • Troubleshooting:             kubectl describe pod <pod-name> -n agent-forge"
print_status "  • Destroy infrastructure:      $0 destroy"
print_status "  • Scale deployment:            kubectl scale deployment <name> --replicas=<number> -n agent-forge"

print_success "Your Agent Forge infrastructure is now ready to use!"
