#!/bin/bash
set -e

# DigitalOcean Testing Script
# Tests the agent framework infrastructure on DigitalOcean

# Script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Default values
ENV="dev"
VERBOSE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
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

# Set up log functions
log() {
    echo "[$(date +%T)] $1"
}

log_success() {
    echo -e "[$(date +%T)] \033[0;32m✅ $1\033[0m"
}

log_error() {
    echo -e "[$(date +%T)] \033[0;31m❌ $1\033[0m"
}

log_warning() {
    echo -e "[$(date +%T)] \033[0;33m⚠️ $1\033[0m"
}

log_info() {
    echo -e "[$(date +%T)] \033[0;34mℹ️ $1\033[0m"
}

# Print test header
log_info "Running Agent Framework tests on DigitalOcean (Environment: $ENV)"
log_info "==================================================================================="

# Test 1: Check if doctl is installed and authenticated
log "Test 1: Checking DigitalOcean CLI"
if ! command -v doctl &> /dev/null; then
    log_error "DigitalOcean CLI (doctl) not found. Please install doctl."
    exit 1
fi

if ! doctl account get &> /dev/null; then
    log_error "Not authenticated with DigitalOcean. Run 'doctl auth init' first."
    exit 1
fi
log_success "DigitalOcean CLI is installed and authenticated"

# Test 2: Check if Kubernetes cluster exists
log "Test 2: Checking Kubernetes cluster"
CLUSTER_NAME="agent-framework-$ENV"
CLUSTER_ID=$(doctl kubernetes cluster list --format ID,Name --no-header | grep "$CLUSTER_NAME" | awk '{print $1}' || echo "")

if [ -z "$CLUSTER_ID" ]; then
    log_error "Kubernetes cluster '$CLUSTER_NAME' not found."
    exit 1
fi
log_success "Kubernetes cluster '$CLUSTER_NAME' exists (ID: $CLUSTER_ID)"

# Test 3: Configure kubectl and check connection
log "Test 3: Testing kubectl connection"
doctl kubernetes cluster kubeconfig save "$CLUSTER_ID" > /dev/null
if ! kubectl get nodes &> /dev/null; then
    log_error "Failed to connect to Kubernetes cluster with kubectl"
    exit 1
fi

NODE_COUNT=$(kubectl get nodes -o name | wc -l)
log_success "Successfully connected to Kubernetes cluster (Nodes: $NODE_COUNT)"

# Test 4: Check core components
log "Test 4: Checking core components"

# Check Linkerd
log "Checking Linkerd..."
if kubectl get namespace linkerd &> /dev/null; then
    if [ "$VERBOSE" = true ]; then
        kubectl get pods -n linkerd
    fi
    LINKERD_STATUS=$(linkerd check 2>/dev/null || echo "Failed")
    if [[ "$LINKERD_STATUS" == *"All checks passed"* ]]; then
        log_success "Linkerd is installed and healthy"
    else
        log_warning "Linkerd is installed but has issues"
        if [ "$VERBOSE" = true ]; then
            linkerd check
        fi
    fi
else
    log_error "Linkerd namespace not found"
fi

# Check Traefik
log "Checking Traefik..."
if kubectl get namespace traefik &> /dev/null; then
    TRAEFIK_PODS=$(kubectl get pods -n traefik -l app=traefik -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    if [[ "$TRAEFIK_PODS" == *"Running"* ]]; then
        log_success "Traefik is running"
        if [ "$VERBOSE" = true ]; then
            kubectl get pods,svc -n traefik
        fi
    else
        log_error "Traefik pods are not running"
        kubectl get pods -n traefik
    fi
else
    log_error "Traefik namespace not found"
fi

# Check Service Registry
log "Checking Service Registry..."
if kubectl get deployment service-registry &> /dev/null; then
    SR_READY=$(kubectl get deployment service-registry -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [ "$SR_READY" -gt 0 ]; then
        log_success "Service Registry is running"
        if [ "$VERBOSE" = true ]; then
            kubectl get deployment,svc service-registry
        fi
    else
        log_error "Service Registry pods are not ready"
        kubectl get pods -l app=service-registry
    fi
else
    log_error "Service Registry deployment not found"
fi

# Test 5: Test network connectivity
log "Test 5: Testing network connectivity"

# Get Service Registry endpoint
SR_SVC=$(kubectl get svc service-registry -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
if [ -n "$SR_SVC" ]; then
    # Create a temporary pod to test connectivity
    log "Creating a test pod to check connectivity..."
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: network-test
  labels:
    app: network-test
spec:
  containers:
  - name: network-test
    image: curlimages/curl:7.82.0
    command: ["sleep", "300"]
  terminationGracePeriodSeconds: 0
EOF

    # Wait for the pod to be ready
    log "Waiting for test pod to be ready..."
    kubectl wait --for=condition=ready pod/network-test --timeout=60s

    # Test connectivity to Service Registry
    log "Testing connectivity to Service Registry..."
    if kubectl exec network-test -- curl -s -o /dev/null -w "%{http_code}" "http://$SR_SVC:8000/health" | grep -q "200"; then
        log_success "Successfully connected to Service Registry"
    else
        log_error "Failed to connect to Service Registry"
    fi

    # Clean up the test pod
    log "Cleaning up test pod..."
    kubectl delete pod network-test --wait=false
else
    log_error "Could not find Service Registry service"
fi

# Test 6: Check for any errors in the logs
log "Test 6: Checking for errors in logs"

# Function to check pod logs for errors
check_pod_logs() {
    local namespace=$1
    local label=$2
    local pod_name=$3
    
    if [ -n "$pod_name" ]; then
        # Check specific pod
        ERROR_COUNT=$(kubectl logs --tail=100 -n "$namespace" "$pod_name" 2>/dev/null | grep -i -E "error|exception|fail" | wc -l)
        if [ "$ERROR_COUNT" -gt 0 ]; then
            log_warning "Found $ERROR_COUNT potential errors in $pod_name logs"
            if [ "$VERBOSE" = true ]; then
                log "Error log excerpts:"
                kubectl logs --tail=100 -n "$namespace" "$pod_name" | grep -i -E "error|exception|fail"
            fi
        else
            log_success "No obvious errors in $pod_name logs"
        fi
    else
        # Check pods with label
        pods=$(kubectl get pods -n "$namespace" -l "$label" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        for pod in $pods; do
            ERROR_COUNT=$(kubectl logs --tail=100 -n "$namespace" "$pod" 2>/dev/null | grep -i -E "error|exception|fail" | wc -l)
            if [ "$ERROR_COUNT" -gt 0 ]; then
                log_warning "Found $ERROR_COUNT potential errors in $pod logs"
                if [ "$VERBOSE" = true ]; then
                    log "Error log excerpts from $pod:"
                    kubectl logs --tail=100 -n "$namespace" "$pod" | grep -i -E "error|exception|fail"
                fi
            else
                log_success "No obvious errors in $pod logs"
            fi
        done
    fi
}

# Check Traefik logs
log "Checking Traefik logs..."
check_pod_logs "traefik" "app=traefik" ""

# Check Service Registry logs
log "Checking Service Registry logs..."
SR_POD=$(kubectl get pods -l app=service-registry -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$SR_POD" ]; then
    check_pod_logs "default" "" "$SR_POD"
else
    log_warning "No Service Registry pod found"
fi

# Final summary
log_info "==================================================================================="
log_info "Test Summary:"

# Count successful, warning, and failed tests
SUCCESS_COUNT=$(grep -c "✅" <<< "$(cat /tmp/test_output.log 2>/dev/null || echo "")")
WARNING_COUNT=$(grep -c "⚠️" <<< "$(cat /tmp/test_output.log 2>/dev/null || echo "")")
ERROR_COUNT=$(grep -c "❌" <<< "$(cat /tmp/test_output.log 2>/dev/null || echo "")")

log_success "$SUCCESS_COUNT checks passed"
if [ "$WARNING_COUNT" -gt 0 ]; then
    log_warning "$WARNING_COUNT warnings"
fi
if [ "$ERROR_COUNT" -gt 0 ]; then
    log_error "$ERROR_COUNT errors"
    exit 1
else
    log_success "All critical checks passed!"
    exit 0
fi
