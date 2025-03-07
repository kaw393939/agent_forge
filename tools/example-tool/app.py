from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import httpx
import os
import asyncio
import uuid
import logging
import json

app = FastAPI(title="Example API Tool")

# Configuration
REGISTRY_URL = os.environ.get("REGISTRY_URL", "http://service-registry:8000")
TOOL_NAME = "Calculator API"
TOOL_VERSION = "1.0.0"
TOOL_ID = str(uuid.uuid4())

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# OpenAPI schema for the tool's endpoints
api_schema = {
    "openapi": "3.0.0",
    "info": {
        "title": TOOL_NAME,
        "version": TOOL_VERSION,
        "description": "A simple calculator API that agents can use for mathematical operations"
    },
    "paths": {
        "/calculate": {
            "post": {
                "summary": "Perform a calculation",
                "description": "Calculate the result of a mathematical expression",
                "requestBody": {
                    "required": True,
                    "content": {
                        "application/json": {
                            "schema": {
                                "type": "object",
                                "properties": {
                                    "expression": {
                                        "type": "string",
                                        "description": "Mathematical expression to evaluate (e.g., '2 + 2')"
                                    }
                                },
                                "required": ["expression"]
                            }
                        }
                    }
                },
                "responses": {
                    "200": {
                        "description": "Calculation result",
                        "content": {
                            "application/json": {
                                "schema": {
                                    "type": "object",
                                    "properties": {
                                        "result": {
                                            "type": "number",
                                            "description": "Calculation result"
                                        },
                                        "expression": {
                                            "type": "string",
                                            "description": "Original expression"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

# Tool registration information
tool_info = {
    "id": TOOL_ID,
    "name": TOOL_NAME,
    "description": "A simple calculator API that agents can use for mathematical operations",
    "version": TOOL_VERSION,
    "host": os.environ.get("HOST", "example-tool"),
    "port": int(os.environ.get("PORT", "8080")),
    "tool_type": "calculator",
    "endpoints": {
        "calculate": {
            "path": "/calculate",
            "method": "POST",
            "description": "Perform a mathematical calculation"
        }
    },
    "schema": api_schema,
    "metadata": {
        "creator": "Example Framework"
    }
}


async def register_with_registry():
    """Register the tool with the service registry"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(f"{REGISTRY_URL}/tools/register", json=tool_info)
            if response.status_code == 200:
                logger.info(f"Successfully registered tool: {TOOL_ID}")
                return response.json()
            else:
                logger.error(f"Failed to register tool: {response.text}")
                return None
    except Exception as e:
        logger.error(f"Error registering tool: {str(e)}")
        return None


async def send_heartbeat():
    """Send a heartbeat to the registry periodically"""
    while True:
        try:
            async with httpx.AsyncClient() as client:
                response = await client.put(f"{REGISTRY_URL}/tools/{TOOL_ID}/heartbeat")
                if response.status_code == 200:
                    logger.debug("Heartbeat sent successfully")
                else:
                    logger.warning(f"Failed to send heartbeat: {response.text}")
        except Exception as e:
            logger.error(f"Error sending heartbeat: {str(e)}")
        
        await asyncio.sleep(20)  # Send heartbeat every 20 seconds


@app.on_event("startup")
async def startup_event():
    """Initialize tool on startup"""
    # Register with the service registry
    registration = await register_with_registry()
    if registration:
        logger.info("Tool registered successfully")
        
        # Start the heartbeat task
        asyncio.create_task(send_heartbeat())
    else:
        logger.error("Failed to register tool with the service registry")


class CalculationRequest(BaseModel):
    expression: str


class CalculationResponse(BaseModel):
    result: float
    expression: str


@app.get("/")
def read_root():
    return {
        "name": TOOL_NAME,
        "version": TOOL_VERSION,
        "id": TOOL_ID,
        "type": "calculator"
    }


@app.post("/calculate", response_model=CalculationResponse)
async def calculate(request: CalculationRequest):
    """
    Perform a mathematical calculation
    """
    try:
        # WARNING: Using eval() is generally unsafe, but used here for simplicity
        # In a production environment, use a safer approach like ast.literal_eval() 
        # or a dedicated math expression parser
        result = eval(request.expression)
        return {
            "result": float(result),
            "expression": request.expression
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Calculation error: {str(e)}")


@app.get("/schema")
def get_schema():
    """
    Get the OpenAPI schema for this tool
    """
    return api_schema


@app.get("/health")
def health_check():
    """Health check endpoint for the tool"""
    return {"status": "healthy"}
