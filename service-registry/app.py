from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from typing import List, Dict, Optional, Literal
import uuid
import time
from datetime import datetime, timedelta

app = FastAPI(title="Agent Framework Service Registry")

# In-memory storage for services (in production, use a persistent database)
agents = {}
tools = {}

# Health check interval (in seconds)
HEALTH_CHECK_INTERVAL = 30
# Service expiration (in seconds)
SERVICE_EXPIRATION = 120


class ServiceBase(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    description: str
    version: str
    host: str
    port: int
    health_endpoint: str = "/health"
    last_seen: float = Field(default_factory=time.time)
    metadata: Dict = {}


class Agent(ServiceBase):
    type: Literal["agent"] = "agent"
    capabilities: List[str] = []
    required_tools: List[str] = []


class Tool(ServiceBase):
    type: Literal["tool"] = "tool"
    tool_type: str
    endpoints: Dict[str, Dict] = {}
    schema: Dict = {}


class ServiceQuery(BaseModel):
    service_type: Optional[Literal["agent", "tool"]] = None
    tool_type: Optional[str] = None
    capabilities: Optional[List[str]] = None
    name: Optional[str] = None


@app.get("/")
def read_root():
    return {"message": "Agent Framework Service Registry", "version": "1.0.0"}


@app.post("/agents/register", response_model=Agent)
def register_agent(agent: Agent):
    agent.last_seen = time.time()
    agents[agent.id] = agent
    return agent


@app.post("/tools/register", response_model=Tool)
def register_tool(tool: Tool):
    tool.last_seen = time.time()
    tools[tool.id] = tool
    return tool


@app.get("/agents", response_model=List[Agent])
def list_agents():
    # Remove expired agents
    current_time = time.time()
    expired_agents = [
        agent_id
        for agent_id, agent in agents.items()
        if current_time - agent.last_seen > SERVICE_EXPIRATION
    ]
    for agent_id in expired_agents:
        agents.pop(agent_id, None)
    
    return list(agents.values())


@app.get("/tools", response_model=List[Tool])
def list_tools():
    # Remove expired tools
    current_time = time.time()
    expired_tools = [
        tool_id
        for tool_id, tool in tools.items()
        if current_time - tool.last_seen > SERVICE_EXPIRATION
    ]
    for tool_id in expired_tools:
        tools.pop(tool_id, None)
    
    return list(tools.values())


@app.get("/agents/{agent_id}", response_model=Agent)
def get_agent(agent_id: str):
    if agent_id not in agents:
        raise HTTPException(status_code=404, detail="Agent not found")
    return agents[agent_id]


@app.get("/tools/{tool_id}", response_model=Tool)
def get_tool(tool_id: str):
    if tool_id not in tools:
        raise HTTPException(status_code=404, detail="Tool not found")
    return tools[tool_id]


@app.post("/discover", response_model=Dict)
def discover_services(query: ServiceQuery):
    """
    Discover services based on query parameters
    """
    matched_agents = []
    matched_tools = []
    
    if query.service_type == "agent" or query.service_type is None:
        for agent in agents.values():
            if query.name and query.name.lower() not in agent.name.lower():
                continue
            if query.capabilities and not all(cap in agent.capabilities for cap in query.capabilities):
                continue
            matched_agents.append(agent)
    
    if query.service_type == "tool" or query.service_type is None:
        for tool in tools.values():
            if query.name and query.name.lower() not in tool.name.lower():
                continue
            if query.tool_type and query.tool_type.lower() != tool.tool_type.lower():
                continue
            matched_tools.append(tool)
    
    return {
        "agents": matched_agents,
        "tools": matched_tools
    }


@app.put("/agents/{agent_id}/heartbeat")
def update_agent_heartbeat(agent_id: str):
    if agent_id not in agents:
        raise HTTPException(status_code=404, detail="Agent not found")
    agents[agent_id].last_seen = time.time()
    return {"status": "ok"}


@app.put("/tools/{tool_id}/heartbeat")
def update_tool_heartbeat(tool_id: str):
    if tool_id not in tools:
        raise HTTPException(status_code=404, detail="Tool not found")
    tools[tool_id].last_seen = time.time()
    return {"status": "ok"}


@app.get("/health")
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}
