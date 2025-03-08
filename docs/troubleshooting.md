# Troubleshooting Guide

This guide helps you diagnose and resolve common issues you might encounter with your Agent Forge deployment. It's organized by deployment type and component to help you quickly find solutions.

## Table of Contents

- [General Troubleshooting Steps](#general-troubleshooting-steps)
- [Docker Deployment Issues](#docker-deployment-issues)
- [Kubernetes Deployment Issues](#kubernetes-deployment-issues)
- [SSL Certificate Issues](#ssl-certificate-issues)
- [DNS Issues](#dns-issues)
- [Service Registry Issues](#service-registry-issues)
- [Agent Issues](#agent-issues)
- [Tool Issues](#tool-issues)
- [Frontend Issues](#frontend-issues)
- [OpenAI API Issues](#openai-api-issues)

## General Troubleshooting Steps

Before diving into specific issues, try these general troubleshooting steps:

1. **Check Logs**: Always start with checking the logs of the affected component
2. **Verify Connectivity**: Ensure network connectivity between components
3. **Check Environment Variables**: Verify all required environment variables are set correctly
4. **Restart Services**: Sometimes a simple restart resolves temporary issues
5. **Check Resource Usage**: Ensure your system has sufficient resources (CPU, memory)

## Docker Deployment Issues

### Container Won't Start

**Symptoms**:
- Docker container fails to start
- `docker-compose up` shows errors

**Solutions**:

1. Check the Docker logs:
   ```bash
   docker logs <container_name>
   ```

2. Verify port availability:
   ```bash
   sudo netstat -tulpn | grep <port_number>
   ```

3. Check for conflicting containers:
   ```bash
   docker ps -a
   ```

4. Verify Docker network:
   ```bash
   docker network ls
   docker network inspect agent-network
   ```

### Service Connectivity Issues

**Symptoms**:
- Services can't communicate with each other
- "Connection refused" errors in logs

**Solutions**:

1. Check if services are on the same network:
   ```bash
   docker network inspect agent-network
   ```

2. Try pinging from one container to another:
   ```bash
   docker exec -it <container_name> ping <other_container_name>
   ```

3. Verify service names match what's in docker-compose.yml

## Kubernetes Deployment Issues

### Pod Status Issues

**Symptoms**:
- Pods stuck in "Pending", "CrashLoopBackOff", or "Error" state
- Pods not running as expected

**Solutions**:

1. Check pod status:
   ```bash
   kubectl get pods -n agent-forge
   ```

2. Check pod details:
   ```bash
   kubectl describe pod <pod-name> -n agent-forge
   ```

3. Check pod logs:
   ```bash
   kubectl logs <pod-name> -n agent-forge
   ```

### ImagePullBackOff Error

**Symptoms**:
- Pod status shows "ImagePullBackOff"
- Images can't be pulled from Docker Hub

**Solutions**:

1. Verify Docker Hub credentials:
   ```bash
   kubectl get secret docker-hub-credentials -n agent-forge -o yaml
   ```

2. Check if images exist in Docker Hub:
   ```bash
   docker pull kaw393939/agent-forge-<component>:latest
   ```

3. Update Docker Hub credentials:
   ```bash
   kubectl delete secret docker-hub-credentials -n agent-forge
   kubectl create secret docker-registry docker-hub-credentials \
     --docker-server=https://index.docker.io/v1/ \
     --docker-username=<your-username> \
     --docker-password=<your-token> \
     --docker-email=<your-email> \
     -n agent-forge
   ```

### CreateContainerConfigError

**Symptoms**:
- Pod status shows "CreateContainerConfigError"
- Containers fail to start due to missing secrets or config

**Solutions**:

1. Check if required secrets exist:
   ```bash
   kubectl get secrets -n agent-forge
   ```

2. Create missing secrets:
   ```bash
   kubectl create secret generic agent-secrets \
     --from-literal=openai-api-key=<your-openai-api-key> \
     -n agent-forge
   ```

3. Restart affected pods:
   ```bash
   kubectl delete pod <pod-name> -n agent-forge
   ```

## SSL Certificate Issues

### Certificate Not Issuing

**Symptoms**:
- Certificate remains in "not ready" state
- HTTPS not working for domains

**Solutions**:

1. Check certificate status:
   ```bash
   kubectl get certificates -n agent-forge
   ```

2. Check certificate request details:
   ```bash
   kubectl get certificaterequests -n agent-forge
   kubectl describe certificaterequest <name> -n agent-forge
   ```

3. Check Let's Encrypt challenges:
   ```bash
   kubectl get challenges -n agent-forge
   kubectl describe challenge <name> -n agent-forge
   ```

4. Verify DNS settings allow Let's Encrypt verification

### Certificate Error in Browser

**Symptoms**:
- Browser shows SSL certificate error
- Certificate doesn't match domain

**Solutions**:

1. Verify TLS configuration in ingress:
   ```bash
   kubectl get ingress -n agent-forge -o yaml
   ```

2. Check if certificate was issued correctly:
   ```bash
   kubectl describe certificate <name> -n agent-forge
   ```

3. Try recreating the certificate:
   ```bash
   kubectl delete certificate <name> -n agent-forge
   # Kubernetes will automatically recreate it
   ```

## DNS Issues

### Domain Not Resolving

**Symptoms**:
- Cannot access services via domain names
- DNS lookup fails

**Solutions**:

1. Check DNS records with your registrar

2. Verify DNS propagation:
   ```bash
   dig +short <your-domain>
   ```

3. Test local resolution by adding entries to `/etc/hosts`

4. Check ingress configuration:
   ```bash
   kubectl get ingress -n agent-forge
   ```

### Wrong IP Resolution

**Symptoms**:
- Domain resolves to incorrect IP address
- Cannot access services despite DNS resolving

**Solutions**:

1. Verify the Load Balancer IP:
   ```bash
   kubectl get service -n ingress-nginx | grep LoadBalancer
   ```

2. Update DNS records with correct IP

3. Check for DNS caching issues by flushing your local DNS cache

## Service Registry Issues

### Registration Failures

**Symptoms**:
- Services fail to register with the registry
- "Connection refused" errors when trying to register

**Solutions**:

1. Check service registry logs:
   ```bash
   kubectl logs -l app=service-registry -n agent-forge
   ```

2. Verify service registry is running:
   ```bash
   kubectl get pod -l app=service-registry -n agent-forge
   ```

3. Check if registry URL is correct in service configurations

### Discovery Failures

**Symptoms**:
- Agents cannot discover tools
- "No tools found" errors in agent logs

**Solutions**:

1. Check if tools are registered:
   ```bash
   curl http://service-registry.agent-forge.svc.cluster.local:8000/discover
   ```

2. Verify tool services are running:
   ```bash
   kubectl get pods -l app=example-tool -n agent-forge
   ```

3. Check registry database is functioning correctly

## Agent Issues

### Agent Not Processing Queries

**Symptoms**:
- Agent returns errors when processing queries
- No response from agent API

**Solutions**:

1. Check agent logs:
   ```bash
   kubectl logs -l app=example-agent -n agent-forge
   ```

2. Verify OpenAI API key is correctly configured:
   ```bash
   kubectl get secret agent-secrets -n agent-forge -o yaml
   ```

3. Check if agent is connected to registry:
   ```bash
   curl http://service-registry.agent-forge.svc.cluster.local:8000/agents
   ```

### OpenAI API Errors

**Symptoms**:
- "Invalid API key" or quota errors in agent logs
- Agent returns errors related to OpenAI

**Solutions**:

1. Update OpenAI API key:
   ```bash
   kubectl delete secret agent-secrets -n agent-forge
   kubectl create secret generic agent-secrets \
     --from-literal=openai-api-key=<your-new-api-key> \
     -n agent-forge
   ```

2. Restart agent pods:
   ```bash
   kubectl delete pod -l app=example-agent -n agent-forge
   ```

## Tool Issues

### Tool Not Responding

**Symptoms**:
- Tool API returns errors or timeouts
- Agent cannot successfully call tools

**Solutions**:

1. Check tool logs:
   ```bash
   kubectl logs -l app=example-tool -n agent-forge
   ```

2. Verify tool service is running:
   ```bash
   kubectl get pod -l app=example-tool -n agent-forge
   ```

3. Check if tool is registered correctly:
   ```bash
   curl http://service-registry.agent-forge.svc.cluster.local:8000/tools
   ```

## Frontend Issues

### Frontend Not Loading

**Symptoms**:
- Streamlit UI doesn't load
- Error messages in browser console

**Solutions**:

1. Check frontend logs:
   ```bash
   kubectl logs -l app=streamlit-frontend -n agent-forge
   ```

2. Verify frontend service is running:
   ```bash
   kubectl get pod -l app=streamlit-frontend -n agent-forge
   ```

3. Check if ingress is correctly configured:
   ```bash
   kubectl get ingress streamlit-frontend-ingress -n agent-forge -o yaml
   ```

### Can't Connect to Agents

**Symptoms**:
- Frontend loads but can't connect to agents
- Error messages when submitting queries

**Solutions**:

1. Check if agent services are running:
   ```bash
   kubectl get pods -l app=example-agent -n agent-forge
   ```

2. Verify connectivity from frontend to agents:
   ```bash
   kubectl exec -it $(kubectl get pod -l app=streamlit-frontend -n agent-forge -o name) -n agent-forge -- curl -I http://example-agent:8080/health
   ```

3. Check agent URLs in frontend configuration

## OpenAI API Issues

### API Key Invalid

**Symptoms**:
- "Invalid API Key" errors in agent logs
- API calls failing with 401 errors

**Solutions**:

1. Verify your API key is valid by testing it outside the system

2. Update the API key secret:
   ```bash
   kubectl delete secret agent-secrets -n agent-forge
   kubectl create secret generic agent-secrets \
     --from-literal=openai-api-key=<your-new-api-key> \
     -n agent-forge
   ```

3. Restart agent pods to pick up the new key:
   ```bash
   kubectl delete pod -l app=example-agent -n agent-forge
   ```

### API Rate Limiting

**Symptoms**:
- "Rate limit exceeded" errors
- Sporadic failures of agent queries

**Solutions**:

1. Check your OpenAI API usage dashboard

2. Implement rate limiting in your agent code

3. Consider upgrading your OpenAI API plan

4. Implement retry logic with exponential backoff in your agent code

## Additional Support

If you're still experiencing issues after trying these troubleshooting steps, please:

1. Gather all relevant logs and error messages
2. Describe your deployment environment in detail
3. Submit an issue on the GitHub repository with this information

For security-related issues, please report them privately through the appropriate channels.
