# DNS Settings for Agent Forge Deployment

## Automated DNS Management

Agent Forge now includes automated DNS management for DigitalOcean domains through the `update_dns.sh` script. This script is integrated with the deployment process and can be run automatically or manually as needed.

## Required DNS Records

The following DNS records are required for a complete Agent Forge deployment:

| Type | Name/Host | Value/Points to | TTL |
|------|-----------|----------------|-----|
| A    | @ (root domain) | <Load Balancer IP> | 1800 (30 min) |
| A    | www       | <Load Balancer IP> | 1800 (30 min) |
| A    | registry  | <Load Balancer IP> | 1800 (30 min) |
| A    | agent     | <Load Balancer IP> | 1800 (30 min) |
| A    | tools     | <Load Balancer IP> | 1800 (30 min) |
| A    | linkerd   | <Load Balancer IP> | 1800 (30 min) |
| A    | traefik   | <Load Balancer IP> | 1800 (30 min) |

## Automated DNS Setup

Our improved setup process handles DNS configuration automatically:

1. **Using the Setup Script**
   ```bash
   ./scripts/setup.sh
   ```
   The setup script will guide you through the entire process, including DNS configuration.

2. **Using the DNS Update Script Directly**
   ```bash
   ./scripts/update_dns.sh <domain> <ip_address> <digital_ocean_token> [subdomains]
   ```
   - `<domain>`: Your domain name (e.g., mywebclass.org)
   - `<ip_address>`: Load balancer IP address
   - `<digital_ocean_token>`: Your DigitalOcean API token
   - `[subdomains]`: Optional comma-separated list of subdomains (defaults to "www,registry,agent,tools,linkerd,traefik")

3. **Features of the DNS Update Script**
   - Automatically creates the domain in DigitalOcean if it doesn't exist
   - Checks for existing records and updates them as needed
   - Creates new records if they don't exist
   - Provides detailed status messages during the process

## Important Notes

- **DNS Propagation Time**: After updating DNS records, changes typically take 5-30 minutes to propagate across the internet when using DigitalOcean DNS.

- **Testing Before DNS Propagation**: The setup includes a utility script to update your local hosts file for testing:
  ```bash
  sudo ./scripts/update_hosts.sh <ip_address> <domain>
  ```
  This will add entries for your main domain and all subdomains to your local /etc/hosts file.

- **SSL Certificates**: After DNS propagation, the application will automatically set up SSL certificates for your domains using cert-manager and Let's Encrypt. Certificate issuance typically takes 2-5 minutes.

- **DNS Record Management**: The DigitalOcean API allows for programmatic management of DNS records, eliminating the need for manual configuration through a web interface.

- **Domain Creation**: If the domain doesn't exist in your DigitalOcean account, the script will create it automatically. You'll need to ensure your domain registrar points to DigitalOcean's nameservers for this to work properly.

## Verification and Troubleshooting

### DNS Verification

After DNS propagation is complete, you can verify your setup using:

```bash
# Check that domains resolve to the correct IP
dig +short mywebclass.org
dig +short www.mywebclass.org
dig +short registry.mywebclass.org

# Test HTTPS connectivity (after cert-manager issues certificates)
curl -I https://mywebclass.org
```

### Kubernetes Certificate Status

Check the status of SSL certificates in Kubernetes:

```bash
# View certificate status
kubectl get certificates -n agent-forge

# Check certificate details
kubectl describe certificate -n agent-forge

# View ingress configuration
kubectl get ingress -n agent-forge
```

### Common DNS Issues

1. **DNS not resolving**: Ensure DigitalOcean API token has read/write access
2. **Certificate issuance failing**: Make sure DNS is properly resolving to your load balancer IP
3. **Domain not found**: Check that domain is correctly configured in DigitalOcean

### Forcing DNS Updates

To force an update to DNS records:

```bash
./scripts/update_dns.sh your-domain.com $(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}') $DIGITAL_OCEAN_TOKEN
```
