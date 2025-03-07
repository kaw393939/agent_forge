from fastapi import FastAPI, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import List, Dict, Optional, Union, Any
import httpx
import os
import asyncio
import uuid
import logging
import json
import re
from openai import OpenAI

app = FastAPI(title="Example LLM Agent")

# Configuration
REGISTRY_URL = os.environ.get("REGISTRY_URL", "http://service-registry:8000")
AGENT_NAME = "Example LLM Agent"
AGENT_VERSION = "1.0.0"
AGENT_ID = str(uuid.uuid4())

# OpenAI configuration
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
OPENAI_MODEL = "gpt-3.5-turbo"

# Initialize OpenAI client
if OPENAI_API_KEY:
    openai_client = OpenAI(api_key=OPENAI_API_KEY)
else:
    logger.warning("OPENAI_API_KEY not set, OpenAI integration will not work")
    openai_client = None

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Store discovered tools
discovered_tools = {}

# Store agent registration ID
agent_info = {
    "id": AGENT_ID,
    "name": AGENT_NAME,
    "description": "An LLM agent that uses OpenAI to process queries and the calculator tool",
    "version": AGENT_VERSION,
    "host": os.environ.get("HOST", "example-agent"),
    "port": int(os.environ.get("PORT", "8080")),
    "capabilities": ["text-processing", "question-answering", "math-processing"],
    "required_tools": ["calculator"],
    "metadata": {
        "model": OPENAI_MODEL
    }
}


async def register_with_registry():
    """Register the agent with the service registry"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(f"{REGISTRY_URL}/agents/register", json=agent_info)
            if response.status_code == 200:
                logger.info(f"Successfully registered agent: {AGENT_ID}")
                return response.json()
            else:
                logger.error(f"Failed to register agent: {response.text}")
                return None
    except Exception as e:
        logger.error(f"Error registering agent: {str(e)}")
        return None


async def send_heartbeat():
    """Send a heartbeat to the registry periodically"""
    while True:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.put(f"{REGISTRY_URL}/agents/{AGENT_ID}/heartbeat")
                if response.status_code == 200:
                    logger.debug("Heartbeat sent successfully")
                else:
                    logger.warning(f"Failed to send heartbeat: {response.text}")
        except Exception as e:
            logger.error(f"Error sending heartbeat: {str(e)}")
        
        await asyncio.sleep(20)  # Send heartbeat every 20 seconds


async def discover_tools():
    """Discover and cache available tools from the registry"""
    global discovered_tools
    while True:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{REGISTRY_URL}/discover",
                    json={"service_type": "tool"}
                )
                
                if response.status_code == 200:
                    data = response.json()
                    tools = {tool["id"]: tool for tool in data.get("tools", [])}
                    
                    # Update our cache of discovered tools
                    discovered_tools = tools
                    logger.info(f"Discovered {len(tools)} tools")
                else:
                    logger.warning(f"Failed to discover tools: {response.text}")
        except Exception as e:
            logger.error(f"Error discovering tools: {str(e)}")
        
        await asyncio.sleep(30)  # Check for new tools every 30 seconds


@app.on_event("startup")
async def startup_event():
    """Initialize agent on startup"""
    # Register with the service registry
    registration = await register_with_registry()
    if registration:
        logger.info("Agent registered successfully")
        
        # Start the heartbeat task
        asyncio.create_task(send_heartbeat())
        
        # Start the tool discovery task
        asyncio.create_task(discover_tools())
    else:
        logger.error("Failed to register agent with the service registry")


class QueryRequest(BaseModel):
    query: str
    context: Optional[Dict] = None


class QueryResponse(BaseModel):
    response: str
    tools_used: List[str] = []
    confidence: float


@app.get("/")
def read_root():
    return {
        "name": AGENT_NAME,
        "version": AGENT_VERSION,
        "id": AGENT_ID
    }


async def call_calculator_tool(expression: str) -> Dict[str, Any]:
    """
    Call the calculator tool to evaluate a mathematical expression
    """
    calculator_tools = [tool for tool in discovered_tools.values() if tool.get("tool_type") == "calculator"]
    
    if not calculator_tools:
        logger.warning("No calculator tool found")
        return {"error": "Calculator tool not available"}
    
    calculator = calculator_tools[0]
    host = calculator.get("host", "example-tool")
    port = calculator.get("port", 8080)
    
    try:
        async with httpx.AsyncClient() as client:
            url = f"http://{host}:{port}/calculate"
            logger.info(f"Calling calculator at {url} with expression: {expression}")
            response = await client.post(url, json={"expression": expression})
            
            if response.status_code == 200:
                result = response.json()
                logger.info(f"Calculator result: {result}")
                return result
            else:
                error_msg = f"Calculator error: {response.text}"
                logger.error(error_msg)
                return {"error": error_msg}
    except Exception as e:
        error_msg = f"Error calling calculator tool: {str(e)}"
        logger.error(error_msg)
        return {"error": error_msg}


async def analyze_query_with_openai(query: str) -> Dict[str, Any]:
    """
    Use OpenAI to analyze the query and determine if it contains a math expression
    """
    if not openai_client:
        return {"requires_calculator": False, "error": "OpenAI API key not configured"}
    
    system_prompt = (
        "You are a helpful assistant that analyzes user queries to determine if they contain mathematical expressions. "
        "If a query contains a mathematical calculation, extract the expression in a format that can be evaluated by a calculator. "
        "Do not attempt to solve complex word problems - only extract direct calculation requests. "
        "Output in JSON format with the following fields:\n"
        "- requires_calculator: boolean indicating if a calculator is needed\n"
        "- expression: the cleaned mathematical expression if requires_calculator is true\n"
        "- explanation: brief explanation of your decision"
    )
    
    try:
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": query}
            ],
            response_format={"type": "json_object"}
        )
        
        analysis = json.loads(response.choices[0].message.content)
        logger.info(f"OpenAI query analysis: {analysis}")
        return analysis
    except Exception as e:
        error_message = f"Error analyzing query with OpenAI: {str(e)}"
        logger.error(error_message)
        return {"requires_calculator": False, "error": error_message}


async def generate_response_with_openai(query: str, calculator_result: Optional[Dict] = None) -> Dict[str, Any]:
    """
    Generate a response using OpenAI, incorporating calculator results if available
    """
    if not openai_client:
        return {"response": "I'm sorry, but I cannot process your request because the OpenAI API key is not configured."}
    
    system_prompt = "You are a helpful assistant that answers user queries clearly and concisely."
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": query}
    ]
    
    # If calculator was used, provide the result
    if calculator_result:
        if "error" in calculator_result:
            calc_message = f"I tried to calculate the expression but encountered an error: {calculator_result['error']}"
        else:
            calc_message = (f"I calculated '{calculator_result['expression']}' and the result is: "
                            f"{calculator_result['result']}")
        
        messages.append({"role": "system", "content": f"You have access to calculation results. {calc_message}"})    
    
    try:
        response = openai_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=messages
        )
        
        return {
            "response": response.choices[0].message.content,
            "tools_used": ["calculator"] if calculator_result and "error" not in calculator_result else [],
            "confidence": 0.95 if calculator_result and "error" not in calculator_result else 0.8
        }
    except Exception as e:
        error_message = f"Error generating response with OpenAI: {str(e)}"
        logger.error(error_message)
        return {
            "response": f"I encountered an error while processing your request: {str(e)}",
            "tools_used": [],
            "confidence": 0.1
        }


@app.post("/query", response_model=QueryResponse)
async def process_query(request: QueryRequest):
    """
    Process a user query, potentially using discovered tools
    """
    query = request.query
    calculator_result = None
    tools_used = []
    
    # Log the tools that are available
    tools_count = len(discovered_tools)
    logger.info(f"Processing query with {tools_count} available tools")
    
    # 1. Analyze the query to determine if it's a calculation
    analysis = await analyze_query_with_openai(query)
    
    # 2. If it's a calculation, use the calculator tool
    if analysis.get("requires_calculator", False):
        expression = analysis.get("expression")
        if expression:
            calculator_result = await call_calculator_tool(expression)
            if calculator_result and "error" not in calculator_result:
                tools_used.append("calculator")
    
    # 3. Generate a response using OpenAI
    response_data = await generate_response_with_openai(query, calculator_result)
    
    return {
        "response": response_data["response"],
        "tools_used": response_data["tools_used"],
        "confidence": response_data["confidence"]
    }


@app.get("/tools")
def list_available_tools():
    """
    List all tools that the agent has discovered
    """
    return {
        "tools": list(discovered_tools.values())
    }


@app.get("/health")
def health_check():
    """Health check endpoint for the agent"""
    return {"status": "healthy"}
