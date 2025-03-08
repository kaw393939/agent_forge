# Kubernetes Deployment Guide

This guide provides detailed instructions for deploying the Agent Forge infrastructure on a Kubernetes cluster using Helm charts. This production-grade deployment includes automatic SSL certificate provisioning, service discovery, and high availability.

## Prerequisites

Before you begin, ensure you have:

- A Kubernetes cluster (we use DigitalOcean Kubernetes Service)
- `kubectl` installed and configured to access your cluster
- Helm v3 installed
- Docker Hub account with pushed images
- Domain name with DNS configured (see [DNS Setup Guide](dns-setup.md))
- OpenAI API key

## Step 1: Prepare Your Environment

1. Clone the repository (if you haven't already):
   ```bash
   git clone https://github.com/yourusername/agent-forge.git
   cd agent-forge
   ```

2. Ensure you have the required environment variables:
   ```bash
   # Create a copy of the template
   cp .env.template .env
   
   # Edit the file with your values
   nano .env
   ```
   
   Key variables include:
   - `OPENAI_API_KEY`: Your OpenAI API key
   - `DOCKER_HUB_TOKEN`: Your Docker Hub access token
   - `DIGITAL_OCEAN_TOKEN`: Your DigitalOcean API token (if applicable)

## Step 2: Build and Push Docker Images

Before deploying to Kubernetes, you need to build and push your Docker images to Docker Hub:

```bash
# Make the script executable if it's not already
chmod +x scripts/build_push_images.sh

# Run the build and push script
./scripts/build_push_images.sh
```

This script will:
- Login to Docker Hub using your credentials
- Build all service images (service registry, agents, tools, frontend)
- Push the images to Docker Hub with "latest" and version tags

## Step 3: Install Prerequisite Components

Certain components should be installed before deploying Agent Forge:

### Install NGINX Ingress Controller

```bash
# Add the ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install the ingress-nginx chart
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --create-namespace \
  --namespace ingress-nginx \
  --set controller.publishService.enabled=true
```

### Install Cert-Manager for SSL Certificates

```bash
# Add the jetstack repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager with CRDs
helm install cert-manager jetstack/cert-manager \
  --create-namespace \
  --namespace cert-manager \
  --set installCRDs=true
```

### Create ClusterIssuer for Let's Encrypt

```bash
# Create a file named cluster-issuer.yaml
cat <<EOF > cluster-issuer.yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: your-email@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Apply the ClusterIssuer
kubectl apply -f cluster-issuer.yaml
```

## Step 4: Create Kubernetes Secrets

Create the necessary secrets for your deployment:

### Docker Hub Credentials

```bash
kubectl create namespace agent-forge

kubectl create secret docker-registry docker-hub-credentials \
  --namespace agent-forge \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=<your-docker-username> \
  --docker-password=<your-docker-hub-token> \
  --docker-email=<your-email>
```

### OpenAI API Key

```bash
kubectl create secret generic agent-secrets \
  --namespace agent-forge \
  --from-literal=openai-api-key=<your-openai-api-key>
```

## Step 5: Deploy Agent Forge with Helm

1. Review and customize the Helm values:
   ```bash
   # Make a copy of the default values
   cp helm/agent-forge/values.yaml helm/agent-forge/my-values.yaml
   
   # Edit your custom values
   nano helm/agent-forge/my-values.yaml
   ```

   Key settings to review include:
   - `global.domain`: Your domain name
   - Docker image repositories and tags
   - Resource requests and limits
   - Ingress hostnames

2. Install the Helm chart:
   ```bash
   helm install agent-forge ./helm/agent-forge \
     --namespace agent-forge \
     --values helm/agent-forge/my-values.yaml
   ```

## Step 6: Verify the Deployment

Check that all components are running correctly:

1. Verify that pods are running:
   ```bash
   kubectl get pods -n agent-forge
   ```

2. Check the status of services:
   ```bash
   kubectl get svc -n agent-forge
   ```

3. Verify the Ingress resources:
   ```bash
   kubectl get ingress -n agent-forge
   ```

4. Check the status of certificate issuance:
   ```bash
   kubectl get certificates -n agent-forge
   ```

## Step 7: Test the Application

After deployment and certificate issuance (which might take a few minutes), you can access your application at:

- Main Frontend: https://mywebclass.org and https://www.mywebclass.org
- Example Agent: https://agent.mywebclass.org
- Example Tool: https://tools.mywebclass.org
- Service Registry: https://registry.mywebclass.org
- Linkerd Dashboard: https://linkerd.mywebclass.org (if enabled)

## Upgrading the Deployment

To upgrade your deployment after making changes:

1. Update Docker images:
   ```bash
   ./scripts/build_push_images.sh
   ```

2. Upgrade the Helm release:
   ```bash
   helm upgrade agent-forge ./helm/agent-forge \
     --namespace agent-forge \
     --values helm/agent-forge/my-values.yaml
   ```

## Removing the Deployment

To remove the entire deployment:

```bash
helm uninstall agent-forge -n agent-forge
```

If you want to remove everything including the namespace:

```bash
kubectl delete namespace agent-forge
```

## Customizing the Deployment

### Scaling Components

You can modify the number of replicas for each component in your values file:

```yaml
exampleAgent:
  replicas: 3  # Increase the number of agent replicas

exampleTool:
  replicas: 2  # Increase the number of tool replicas
```

Then upgrade your deployment:

```bash
helm upgrade agent-forge ./helm/agent-forge \
  --namespace agent-forge \
  --values helm/agent-forge/my-values.yaml
```

### Adding Custom Agents or Tools

To add new agents or tools:

1. Create a new template file in `helm/agent-forge/templates/`
2. Add configuration to the `values.yaml` file
3. Build and push the new Docker images
4. Upgrade the deployment

### Modifying Resource Limits

Adjust CPU and memory limits in your values file:

```yaml
exampleAgent:
  resources:
    requests:
      memory: "512Mi"  # Increase memory request
      cpu: "200m"      # Increase CPU request
    limits:
      memory: "1Gi"    # Increase memory limit
      cpu: "1000m"     # Increase CPU limit
```

## Troubleshooting

If you encounter issues, refer to the [Troubleshooting Guide](troubleshooting.md) for solutions to common problems.

Common issues include:
- Pod startup failures due to missing secrets
- Certificate issuance failures due to DNS misconfiguration
- ImagePullBackOff errors due to Docker Hub authentication issues

For detailed diagnostics, check the pod logs:

```bash
kubectl logs -n agent-forge <pod-name>
```

## Next Steps

After successful deployment, consider:

1. [Setting up monitoring and alerting](monitoring.md)
2. [Implementing automated backups](backups.md)
3. [Configuring CI/CD pipelines](ci-cd.md) for automatic deployment
