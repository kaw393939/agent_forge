import streamlit as st
import httpx
import json
from typing import Dict, List, Optional
import os

# Configure page
st.set_page_config(
    page_title="MyWebClass.org - LLM Agent Hub",
    page_icon="🤖",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Constants
# Inside Docker, use service-registry:8000, outside Docker use localhost:8005
REGISTRY_URL = os.environ.get("REGISTRY_URL", "http://service-registry:8000")

# Debug flag to show connection details
DEBUG = os.environ.get("DEBUG", "false").lower() == "true"

# Session state initialization
if "conversation_history" not in st.session_state:
    st.session_state.conversation_history = []
if "current_agent" not in st.session_state:
    st.session_state.current_agent = None
if "available_agents" not in st.session_state:
    st.session_state.available_agents = []
if "available_tools" not in st.session_state:
    st.session_state.available_tools = []

# Sidebar - Agent Selection
st.sidebar.title("🤖 Agent Selection")

async def fetch_agents():
    """Fetch available agents from the service registry"""
    try:
        async with httpx.AsyncClient() as client:
            if DEBUG:
                st.sidebar.info(f"Connecting to registry at {REGISTRY_URL}/agents")
            response = await client.get(f"{REGISTRY_URL}/agents")
            if response.status_code == 200:
                return response.json()
            else:
                st.sidebar.error(f"Failed to fetch agents: {response.status_code}")
                return []
    except Exception as e:
        st.sidebar.error(f"Error connecting to service registry: {str(e)}")
        # Try alternative URL if initial connection fails (for local debugging)
        if "service-registry" in REGISTRY_URL:
            try:
                alt_url = "http://localhost:8005"
                if DEBUG:
                    st.sidebar.info(f"Trying alternative URL: {alt_url}/agents")
                async with httpx.AsyncClient() as client:
                    response = await client.get(f"{alt_url}/agents")
                    if response.status_code == 200:
                        return response.json()
            except Exception as alt_e:
                if DEBUG:
                    st.sidebar.error(f"Alternative connection also failed: {str(alt_e)}")
        return []

async def fetch_tools():
    """Fetch available tools from the service registry"""
    try:
        async with httpx.AsyncClient() as client:
            if DEBUG:
                st.sidebar.info(f"Connecting to registry at {REGISTRY_URL}/tools")
            response = await client.get(f"{REGISTRY_URL}/tools")
            if response.status_code == 200:
                return response.json()
            else:
                st.sidebar.error(f"Failed to fetch tools: {response.status_code}")
                return []
    except Exception as e:
        st.sidebar.error(f"Error connecting to service registry: {str(e)}")
        # Try alternative URL if initial connection fails (for local debugging)
        if "service-registry" in REGISTRY_URL:
            try:
                alt_url = "http://localhost:8005"
                if DEBUG:
                    st.sidebar.info(f"Trying alternative URL: {alt_url}/tools")
                async with httpx.AsyncClient() as client:
                    response = await client.get(f"{alt_url}/tools")
                    if response.status_code == 200:
                        return response.json()
            except Exception as alt_e:
                if DEBUG:
                    st.sidebar.error(f"Alternative connection also failed: {str(alt_e)}")
        return []

def load_agents_and_tools():
    """Load available agents and tools"""
    import asyncio
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    agents = loop.run_until_complete(fetch_agents())
    tools = loop.run_until_complete(fetch_tools())
    
    st.session_state.available_agents = agents
    st.session_state.available_tools = tools
    
    loop.close()

if st.sidebar.button("Refresh Agents & Tools"):
    load_agents_and_tools()

# Automatic loading of agents on first run
if not st.session_state.available_agents:
    load_agents_and_tools()

# Display available agents
if st.session_state.available_agents:
    agent_options = {f"{agent['name']} (v{agent['version']})": agent for agent in st.session_state.available_agents}
    selected_agent_name = st.sidebar.selectbox(
        "Select an Agent", 
        options=list(agent_options.keys()),
        index=0 if st.session_state.current_agent is None else list(agent_options.keys()).index(st.session_state.current_agent)
    )
    
    if selected_agent_name:
        st.session_state.current_agent = selected_agent_name
        selected_agent = agent_options[selected_agent_name]
        
        # Display agent details
        st.sidebar.subheader("Agent Details")
        st.sidebar.markdown(f"**ID:** `{selected_agent['id']}`")
        st.sidebar.markdown(f"**Description:** {selected_agent['description']}")
        st.sidebar.markdown(f"**Capabilities:** {', '.join(selected_agent['capabilities'])}")
        
        # Display required tools
        if selected_agent['required_tools']:
            st.sidebar.subheader("Required Tools")
            for tool_type in selected_agent['required_tools']:
                matching_tools = [tool for tool in st.session_state.available_tools if tool['tool_type'] == tool_type]
                if matching_tools:
                    st.sidebar.success(f"✅ {tool_type}: {len(matching_tools)} available")
                else:
                    st.sidebar.error(f"❌ {tool_type}: Not available")
else:
    st.sidebar.warning("No agents available. Make sure the service registry is running.")

# Display available tools
st.sidebar.subheader("Available Tools")
if st.session_state.available_tools:
    tool_types = set(tool['tool_type'] for tool in st.session_state.available_tools)
    for tool_type in tool_types:
        count = len([t for t in st.session_state.available_tools if t['tool_type'] == tool_type])
        st.sidebar.markdown(f"- **{tool_type}**: {count} available")
else:
    st.sidebar.info("No tools registered yet.")

# Main area
st.title("🤖 MyWebClass.org LLM Agent Hub")

if not st.session_state.current_agent:
    st.info("👈 Please select an agent from the sidebar to get started")
    
    # Welcome message
    st.markdown("""
    ## Welcome to the MyWebClass.org LLM Agent Hub!
    
    This platform enables you to interact with various LLM agents that have access to a robust set of tools. 
    Our system is designed to:
    
    - **Discover and use agents** dynamically as they come online
    - **Share conversation context** between different agents
    - **Provide specialized capabilities** through different agent personalities
    
    To get started, select an agent from the sidebar and begin your conversation.
    """)
    
    # Show system status
    st.subheader("System Status")
    col1, col2 = st.columns(2)
    with col1:
        st.metric("Agents Available", len(st.session_state.available_agents))
    with col2:
        st.metric("Tools Available", len(st.session_state.available_tools))
        
else:
    selected_agent = agent_options[st.session_state.current_agent]
    
    # Display conversation history
    st.subheader("Conversation")
    for i, message in enumerate(st.session_state.conversation_history):
        if message["role"] == "user":
            st.markdown(f"**You:** {message['content']}")
        else:
            st.markdown(f"**{message['agent_name']}:** {message['content']}")
            if 'tools_used' in message and message['tools_used']:
                st.caption(f"*Tools used: {', '.join(message['tools_used'])}*")
    
    # Input for user message
    user_input = st.text_area("Your message:", height=100)
    
    async def send_message_to_agent(agent, message):
        """Send a message to an agent and get a response"""
        try:
            agent_host = agent["host"]
            agent_port = agent["port"]
            agent_url = f"http://{agent_host}:{agent_port}/query"
            
            payload = {
                "query": message,
                "context": {
                    "conversation_history": [
                        {
                            "role": msg["role"],
                            "content": msg["content"]
                        } for msg in st.session_state.conversation_history
                    ]
                }
            }
            
            async with httpx.AsyncClient() as client:
                response = await client.post(agent_url, json=payload, timeout=30.0)
                if response.status_code == 200:
                    return response.json()
                else:
                    st.error(f"Error from agent: {response.status_code} - {response.text}")
                    return None
        except Exception as e:
            st.error(f"Error communicating with agent: {str(e)}")
            return None
    
    if st.button("Send"):
        if user_input.strip():
            # Add user message to history
            st.session_state.conversation_history.append({
                "role": "user",
                "content": user_input,
                "agent_name": None
            })
            
            # Get response from agent
            import asyncio
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            with st.spinner(f"Waiting for {selected_agent['name']} to respond..."):
                response = loop.run_until_complete(send_message_to_agent(selected_agent, user_input))
            
            loop.close()
            
            if response:
                # Add agent response to history
                st.session_state.conversation_history.append({
                    "role": "assistant",
                    "content": response["response"],
                    "agent_name": selected_agent["name"],
                    "tools_used": response.get("tools_used", []),
                    "confidence": response.get("confidence", 0)
                })
            
            # Rerun to update the UI
            st.experimental_rerun()

# Footer
st.markdown("---")
st.markdown("MyWebClass.org LLM Agent Hub - Powered by Agent Framework")
