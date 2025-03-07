# Setting Up GitHub Actions Secrets

To enable automatic building and deployment of Docker images, you need to set up the following secrets in your GitHub repository:

1. Go to your GitHub repository (https://github.com/kaw393939/agent_forge)
2. Navigate to "Settings" > "Secrets and variables" > "Actions"
3. Add the following repository secrets:

## Required Secrets

| Secret Name | Description |
|-------------|-------------|
| `DOCKER_HUB_TOKEN` | Your Docker Hub access token |
| `DROPLET_IP` | IP address of your DigitalOcean droplet (e.g., 192.81.219.5) |
| `SSH_PRIVATE_KEY` | SSH private key for accessing your DigitalOcean droplet |

## Steps to Generate Secrets

### Docker Hub Token
The Docker Hub token has already been added to your .env file. Copy this value to the GitHub secret.

### SSH Private Key
Generate an SSH key pair if you don't already have one:
```
ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f ~/.ssh/agent_forge_deploy
```

Add the private key to GitHub secrets and the public key to your DigitalOcean droplet:
```
cat ~/.ssh/agent_forge_deploy     # Copy this to SSH_PRIVATE_KEY GitHub secret
cat ~/.ssh/agent_forge_deploy.pub # Add this to ~/.ssh/authorized_keys on your droplet
```

### Droplet IP
Add the IP address of your DigitalOcean droplet as a secret:
```
DROPLET_IP=192.81.219.5  # Replace with your actual droplet IP
```
