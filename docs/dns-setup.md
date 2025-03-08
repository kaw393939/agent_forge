# DNS Configuration Guide

This guide explains how to configure DNS settings for your Agent Forge deployment. Proper DNS configuration is essential for making your applications accessible via domain names and for setting up SSL certificates.

## Overview

The Agent Forge infrastructure requires several DNS records to route traffic to different components of the system. All records point to the same DigitalOcean Load Balancer IP address, with the specific service routing handled by the Kubernetes Ingress controller.

## DigitalOcean Load Balancer IP Address

Your DigitalOcean Kubernetes cluster automatically provisions a Load Balancer with these IP addresses:

- **IPv4**: 143.244.214.245
- **IPv6**: 2604:a880:400:d1:0:1:2eae:9001

## Required DNS Records

Configure the following DNS records with your domain registrar (e.g., GoDaddy):

| Type | Name/Host | Value/Points to | TTL |
|------|-----------|----------------|-----|
| A    | @ (root domain) | 143.244.214.245 | 3600 (1 hour) |
| A    | www       | 143.244.214.245 | 3600 (1 hour) |
| A    | registry  | 143.244.214.245 | 3600 (1 hour) |
| A    | agent     | 143.244.214.245 | 3600 (1 hour) |
| A    | tools     | 143.244.214.245 | 3600 (1 hour) |
| A    | linkerd   | 143.244.214.245 | 3600 (1 hour) |
| A    | traefik   | 143.244.214.245 | 3600 (1 hour) |

## Step-by-Step Configuration (GoDaddy)

1. **Log in to your GoDaddy account**
   - Go to godaddy.com and sign in with your credentials

2. **Navigate to your domain's DNS settings**
   - Go to "My Products" 
   - Find your domain (e.g., mywebclass.org)
   - Click on "DNS" or "Manage DNS"

3. **Update your DNS records**
   - Add or update each of the A records listed in the table above
   - Make sure to use the correct Name/Host values exactly as shown

4. **Save your changes**
   - Click "Save" after updating all records

## DNS Propagation and Testing

### DNS Propagation Time

After updating your DNS records, it may take up to 24-48 hours for the changes to propagate fully across the internet, though often it happens much faster (within a few hours).

### Testing Before Full Propagation

While waiting for DNS propagation, you can test your application by modifying your local hosts file:

#### On Linux/macOS:

Edit `/etc/hosts` with sudo privileges:

```bash
sudo nano /etc/hosts
```

Add the following entries:

```
143.244.214.245  mywebclass.org
143.244.214.245  www.mywebclass.org
143.244.214.245  registry.mywebclass.org
143.244.214.245  agent.mywebclass.org
143.244.214.245  tools.mywebclass.org
143.244.214.245  linkerd.mywebclass.org
143.244.214.245  traefik.mywebclass.org
```

#### On Windows:

Edit `C:\Windows\System32\drivers\etc\hosts` with administrator privileges and add the same entries.

## SSL Certificates

After DNS propagation, the application will automatically set up SSL certificates for your domains using cert-manager and Let's Encrypt. This process may take a few minutes.

## Verification

After DNS propagation is complete, you can verify your setup using these commands:

```bash
# Check that all domains resolve to the correct IP
dig +short mywebclass.org
dig +short www.mywebclass.org
dig +short registry.mywebclass.org
dig +short agent.mywebclass.org
dig +short tools.mywebclass.org
dig +short linkerd.mywebclass.org
dig +short traefik.mywebclass.org

# Test HTTPS connectivity (should work after cert-manager has issued certificates)
curl -I https://mywebclass.org
```

## Troubleshooting DNS Issues

### Common Issues

1. **DNS Not Resolving**
   - Verify your DNS records are correctly configured
   - Check if enough time has passed for DNS propagation
   - Try using a different DNS server to test resolution

2. **Cannot Access Services**
   - Ensure the Load Balancer is properly configured
   - Check that Ingress resources have the correct hostnames
   - Verify that your firewall isn't blocking traffic

3. **SSL Certificate Errors**
   - Check cert-manager logs for any issuance failures
   - Verify that Let's Encrypt can reach your domains for validation
   - Ensure Ingress resources have the correct TLS configuration

### Diagnostic Commands

```bash
# Check the status of your certificates
kubectl get certificates -n agent-forge

# Check the status of certificate requests
kubectl get certificaterequests -n agent-forge

# Check the status of challenges (for Let's Encrypt validation)
kubectl get challenges -n agent-forge

# Check ingress resources
kubectl get ingress -n agent-forge
```

## Next Steps

Once your DNS is properly configured and certificates are issued, you can access your applications at:

- Main Frontend: https://mywebclass.org and https://www.mywebclass.org
- Example Agent: https://agent.mywebclass.org
- Example Tool: https://tools.mywebclass.org
- Service Registry: https://registry.mywebclass.org
- Linkerd Dashboard: https://linkerd.mywebclass.org
