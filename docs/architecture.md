# System Architecture

This document explains the architecture of the Agent Forge infrastructure, covering both local development (Docker) and production (Kubernetes) deployment models.

## Overview

Agent Forge is designed as a modular, microservices-based system that enables the deployment and orchestration of LLM-powered agents and tools. The architecture prioritizes:

- **Scalability**: Components can be scaled independently
- **Flexibility**: Easy to add new agents and tools
- **Discoverability**: Service registry enables dynamic discovery
- **Security**: End-to-end encryption and authentication
- **Maintainability**: Clear separation of concerns

## System Components

### Core Services

![Architecture Diagram](../assets/architecture-diagram.png)

#### Service Registry

The central registration and discovery service that tracks:
- Available agents and their capabilities
- Available API tools and their functions
- Health and status information
- Routing information

**Technical Details**:
- Fast API-based REST service
- In-memory database for development
- PostgreSQL database for production
- Heartbeat mechanism for health checks

#### Example Agent

A demonstration LLM agent that:
- Registers with the Service Registry
- Discovers available tools through the registry
- Processes natural language queries
- Uses the OpenAI API for language processing
- Calls appropriate tools based on query content

**Technical Details**:
- Python-based FastAPI service
- OpenAI API integration
- Dynamic tool discovery and invocation

#### Example Tool (Calculator)

A demonstration API tool that:
- Registers with the Service Registry
- Provides mathematical calculation functions
- Exposes a REST API for agent interaction

**Technical Details**:
- Python-based FastAPI service
- Self-documenting API with schema
- Stateless design for scalability

#### Streamlit Frontend

The user interface that:
- Provides a web-based interface for interacting with agents
- Submits queries to the appropriate agent
- Displays responses and interaction history
- Offers configuration options

**Technical Details**:
- Streamlit-based web application
- Responsive design
- Direct integration with agent APIs

### Infrastructure Components

#### Local Development (Docker)

For local development, the infrastructure includes:

- **Traefik**: Handles routing and SSL termination
- **Watchtower**: Automatic container updates
- **Docker Network**: Isolated network for services
- **Docker Volumes**: Persistent storage for development

#### Production Deployment (Kubernetes)

For production deployment, the infrastructure includes:

- **NGINX Ingress Controller**: Manages external traffic
- **Cert-Manager**: Automatic SSL certificate provisioning
- **Linkerd Service Mesh**: Observability, mTLS, and traffic management
- **Helm Charts**: Packaged deployment configurations
- **Kubernetes Secrets**: Secure credential management

## Communication Flow

1. **User Interaction**:
   - User accesses the Streamlit frontend via web browser
   - User enters a natural language query

2. **Query Processing**:
   - Frontend sends query to the appropriate agent
   - Agent processes the query using OpenAI API
   - Agent determines required tools by analyzing the query

3. **Tool Discovery and Invocation**:
   - Agent queries Service Registry for available tools
   - Agent selects appropriate tool(s) based on query analysis
   - Agent calls tool API(s) with extracted parameters

4. **Response Generation**:
   - Agent receives tool response(s)
   - Agent formulates a natural language response
   - Response is sent back to frontend for display

## Deployment Architecture

### Docker Deployment (Development)

```
                                      +----------------+
                                      |                |
                                 +--->+ Streamlit UI   |
                                 |    |                |
                                 |    +----------------+
                                 |
+----------------+     +---------+----+    +----------------+
|                |     |              |    |                |
| Traefik Router +---->+ Example Agent+--->+ Example Tool   |
|                |     |              |    |                |
+----------------+     +---------+----+    +----------------+
                                 |
                                 |    +----------------+
                                 |    |                |
                                 +--->+ Service Registry|
                                      |                |
                                      +----------------+
```

### Kubernetes Deployment (Production)

```
                                  +--------------------+
                                  |                    |
                             +--->+ Streamlit Frontend |
                             |    |                    |
                             |    +--------------------+
                             |
+---------------------+      |    +--------------------+
|                     |      |    |                    |
| NGINX Ingress       +------+--->+ Example Agent      +-----+
| Controller          |      |    |                    |     |
|                     |      |    +--------------------+     |
+---------------------+      |                               |
                             |    +--------------------+     |
                             |    |                    |     |
                             +--->+ Service Registry   |<----+
                             |    |                    |     |
                             |    +--------------------+     |
                             |                               |
                             |    +--------------------+     |
                             |    |                    |     |
                             +--->+ Example Tool       +<----+
                                  |                    |
                                  +--------------------+
```

## Security Architecture

### Authentication

- **API Authentication**: Service-to-service authentication using API keys
- **User Authentication**: OAuth2 or API key-based (for frontend-to-agent communication)
- **Kubernetes Secrets**: Secure storage for credentials

### Encryption

- **TLS**: All external communications encrypted via Let's Encrypt certificates
- **mTLS**: Service-to-service encryption in Kubernetes via Linkerd

### Authorization

- **Role-Based Access**: Different access levels for service-to-service communication
- **Namespace Isolation**: Kubernetes namespace-based isolation for security boundaries

## Scaling Architecture

The system is designed to scale horizontally across all components:

- **Agents**: Multiple instances can be deployed with load balancing
- **Tools**: Each tool can scale independently based on demand
- **Service Registry**: Can be clustered for high availability
- **Frontend**: Multiple instances behind load balancer

## Data Flow

1. **Registration**: Services register with the Service Registry upon startup
2. **Discovery**: Agents discover available tools via registry
3. **Queries**: User queries flow from frontend to agents
4. **Tool Invocation**: Agents call tools as needed based on query analysis
5. **Responses**: Results flow back to the user via the agent and frontend

## Monitoring and Observability

- **Linkerd Dashboard**: Service mesh metrics and monitoring
- **Application Logs**: Centralized logging via Kubernetes
- **Health Checks**: Regular service health reporting
- **Registry Status**: Service status tracking in the registry

## Deployment Process

The deployment process follows these steps:

1. **Build**: Docker images built and pushed to Docker Hub
2. **Configure**: Configuration settings applied via Helm values
3. **Deploy**: Helm chart installed to Kubernetes cluster
4. **Verify**: Health checks confirm successful deployment
5. **Monitor**: Ongoing monitoring via Linkerd and logs
