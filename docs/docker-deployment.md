# Docker Compose Deployment Guide

This guide explains how to set up a local development environment for Agent Forge using Docker Compose. This approach is ideal for development, testing, and small-scale deployments.

## Prerequisites

Before you begin, make sure you have:

- Docker and Docker Compose installed
- Git installed
- OpenAI API key
- Local domain names set up in your hosts file (optional, for local testing)

## Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/agent-forge.git
cd agent-forge
```

## Step 2: Set Up Environment Variables

Create a `.env` file in the root directory:

```bash
# Copy the template
cp .env.template .env

# Edit the .env file
nano .env
```

At minimum, you need to set:

```
OPENAI_API_KEY=your_openai_api_key_here
```

## Step 3: Configure Local Domains (Optional)

For testing with domain names locally, add the following entries to your hosts file:

### On Linux/macOS:

```bash
sudo nano /etc/hosts
```

Add these lines:

```
127.0.0.1  mywebclass.org
127.0.0.1  www.mywebclass.org
127.0.0.1  registry.mywebclass.org
127.0.0.1  agent.mywebclass.org
127.0.0.1  tools.mywebclass.org
127.0.0.1  traefik.mywebclass.org
```

### On Windows:

Edit `C:\Windows\System32\drivers\etc\hosts` with administrator privileges and add the same entries.

## Step 4: Start the Docker Compose Stack

From the root directory of the project:

```bash
docker-compose up -d
```

This command will:
- Pull all necessary Docker images
- Create a Docker network for the services
- Start all services defined in docker-compose.yml

To see the logs in real-time:

```bash
docker-compose logs -f
```

## Step 5: Verify the Services

After starting the stack, verify that all services are running:

```bash
docker-compose ps
```

You should see all services running without errors. If any service has exited, check its logs:

```bash
docker-compose logs [service-name]
```

## Step 6: Access the Applications

You can now access the different components of the system:

- **Main Frontend**: http://mywebclass.org or http://localhost:8502
- **Example Agent**: http://agent.mywebclass.org/example or directly at http://localhost (Traefik routes based on host headers)
- **Example Tool**: http://tools.mywebclass.org/calculator
- **Service Registry**: http://registry.mywebclass.org or http://localhost:8005
- **Traefik Dashboard**: http://traefik.mywebclass.org:8888

## Step 7: Development Workflow

The Docker Compose setup is configured for development with volume mounts that enable live code reloading:

1. **Edit Code**: Modify code in the respective directories:
   - `./service-registry/` for Service Registry
   - `./agents/example-agent/` for Example Agent
   - `./tools/example-tool/` for Example Tool
   - `./frontend/streamlit/` for Streamlit Frontend

2. **Auto-Reload**: Changes will be automatically detected and services will reload thanks to the mounted volumes and reload flags in the commands.

3. **Logs**: Monitor logs to see the effects of your changes:
   ```bash
   docker-compose logs -f example-agent
   ```

## Common Tasks

### Stop All Services

```bash
docker-compose down
```

### Rebuild a Specific Service

If you've made changes to a Dockerfile:

```bash
docker-compose build [service-name]
docker-compose up -d [service-name]
```

### Reset All Services and Data

```bash
docker-compose down
docker-compose up -d
```

### Update Docker Images

To pull the latest versions of all images:

```bash
docker-compose pull
docker-compose up -d
```

## Docker Compose Configuration Explained

The `docker-compose.yml` file defines the following services:

### Traefik

```yaml
traefik:
  image: traefik:v2.10
  # Configuration omitted for brevity
```

Traefik acts as a reverse proxy and load balancer, routing traffic to the appropriate services based on domain names and paths.

### Service Registry

```yaml
service-registry:
  image: kaw393939/agent-forge-service-registry:latest
  # Configuration omitted for brevity
```

The Service Registry provides a central location for agents and tools to register and discover each other.

### Example Agent

```yaml
example-agent:
  image: kaw393939/agent-forge-example-agent:latest
  # Configuration omitted for brevity
```

A demonstration agent that uses OpenAI's API and can discover and use tools through the Service Registry.

### Example Tool

```yaml
example-tool:
  image: kaw393939/agent-forge-example-tool:latest
  # Configuration omitted for brevity
```

A simple calculator tool that demonstrates how to create a tool that can be discovered and used by agents.

### Streamlit Frontend

```yaml
streamlit:
  image: kaw393939/agent-forge-streamlit:latest
  # Configuration omitted for brevity
```

A user-friendly web interface built with Streamlit that allows users to interact with the agents.

## Customizing Docker Compose

### Changing Ports

You can modify the port mappings in the `docker-compose.yml` file. For example, to change the Streamlit port from 8502:

```yaml
streamlit:
  ports:
    - "8510:8501"  # Change 8502 to 8510
```

### Adding New Services

To add a new service, add a new service block to the `docker-compose.yml` file:

```yaml
my-new-service:
  image: myimage:latest
  volumes:
    - ./my-new-service:/app
  environment:
    - REGISTRY_URL=http://service-registry:8000
  networks:
    - agent-network
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.my-new-service.rule=Host(`myservice.mywebclass.org`)"
    - "traefik.http.services.my-new-service.loadbalancer.server.port=8080"
```

### Modifying Environment Variables

You can add additional environment variables to services by expanding the `environment` section:

```yaml
example-agent:
  environment:
    - REGISTRY_URL=http://service-registry:8000
    - OPENAI_API_KEY=${OPENAI_API_KEY}
    - MY_NEW_VAR=some_value
```

## Troubleshooting

### Service Won't Start

Check the logs for errors:

```bash
docker-compose logs [service-name]
```

Common issues include:
- Missing environment variables
- Port conflicts
- Volume mount issues

### Connection Refused Errors

Ensure the service is running and the port is correctly mapped:

```bash
docker-compose ps
```

Check if the service is listening on the expected port inside the container:

```bash
docker-compose exec [service-name] netstat -tulpn
```

### OpenAI API Errors

If the example agent is not working, check:
- That you've set the `OPENAI_API_KEY` in your `.env` file
- That the API key is valid and has sufficient credits
- The logs for any API-related errors

```bash
docker-compose logs example-agent
```

## Next Steps

After setting up your local development environment, consider:

1. Exploring the [System Architecture](architecture.md) to understand how components interact
2. Reviewing the code in each service to understand its functionality
3. Creating your own agent or tool by copying and modifying the example templates
4. Preparing for [Kubernetes Deployment](kubernetes-deployment.md) when you're ready for production

For any issues not covered here, refer to the comprehensive [Troubleshooting Guide](troubleshooting.md).
