#!/usr/bin/env python3
"""
TraceLoop Sidecar - OpenLLMetry Tracing Proxy
This sidecar uses OpenLLMetry (Traceloop SDK) to automatically instrument Ollama API calls.
It acts as a transparent proxy that adds LLM-specific tracing.
"""
import os
import json
import requests
from flask import Flask, request, Response
from traceloop.sdk import Traceloop
from traceloop.sdk.decorators import workflow, task
from opentelemetry import trace

app = Flask(__name__)

# Configuration
OLLAMA_UPSTREAM = os.getenv("OLLAMA_UPSTREAM", "http://ollama:11434")
OTEL_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")
SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "traceloop-sidecar")
TRACED_SERVICE_NAME = os.getenv("TRACED_SERVICE_NAME", "ollama-app")

print("=" * 70)
print("TraceLoop Sidecar - OpenLLMetry Tracing Proxy")
print("=" * 70)
print(f"Upstream Ollama: {OLLAMA_UPSTREAM}")
print(f"OTEL Endpoint: {OTEL_ENDPOINT}")
print(f"Service Name: {SERVICE_NAME}")
print(f"Traced Service: {TRACED_SERVICE_NAME}")
print("=" * 70)


def init_tracing():
    """Initialize OpenLLMetry (Traceloop SDK)"""
    Traceloop.init(
        app_name=TRACED_SERVICE_NAME,  # Use the application name, not sidecar name
        disable_batch=False,
        exporter_otlp_endpoint=OTEL_ENDPOINT,
        # Enable LLM-specific instrumentation
        should_enrich_metrics=True,
    )
    print("✓ OpenLLMetry (Traceloop SDK) initialized successfully")


# Initialize tracing on startup
init_tracing()
tracer = trace.get_tracer(__name__)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": SERVICE_NAME}, 200


@task(name="ollama_api_call")
def proxy_ollama_request(method, path, headers, data, query_string):
    """
    Proxy request to Ollama with OpenLLMetry tracing.
    The @task decorator automatically creates spans and adds LLM attributes.
    """
    # Build upstream URL
    upstream_url = f"{OLLAMA_UPSTREAM}/{path}"
    if query_string:
        upstream_url += f"?{query_string.decode()}"
    
    # Parse request data for logging
    request_data = None
    if data:
        try:
            request_data = json.loads(data)
        except:
            request_data = data.decode('utf-8', errors='ignore')
    
    # Get current span to add custom attributes
    current_span = trace.get_current_span()
    
    # Add custom attributes
    current_span.set_attribute("http.method", method)
    current_span.set_attribute("http.url", upstream_url)
    current_span.set_attribute("http.target", f"/{path}")
    current_span.set_attribute("llm.system", "ollama")
    
    # Extract and add LLM-specific attributes
    if request_data and isinstance(request_data, dict):
        if "model" in request_data:
            current_span.set_attribute("llm.model", request_data["model"])
        
        # For chat API
        if "messages" in request_data:
            messages = request_data["messages"]
            if messages and len(messages) > 0:
                last_message = messages[-1]
                if "content" in last_message:
                    prompt = last_message["content"]
                    current_span.set_attribute("llm.prompts", prompt[:1000])
                    current_span.set_attribute("llm.request.type", "chat")
        
        # For generate API
        if "prompt" in request_data:
            current_span.set_attribute("llm.prompts", request_data["prompt"][:1000])
            current_span.set_attribute("llm.request.type", "completion")
    
    # Log the request
    print(f"\n[PROXY] {method} /{path}")
    if request_data and isinstance(request_data, dict):
        if "model" in request_data:
            print(f"[PROXY] Model: {request_data['model']}")
        if "messages" in request_data and request_data["messages"]:
            print(f"[PROXY] Prompt: {request_data['messages'][-1].get('content', '')[:100]}...")
        elif "prompt" in request_data:
            print(f"[PROXY] Prompt: {request_data['prompt'][:100]}...")
    
    try:
        # Forward request to upstream Ollama
        upstream_response = requests.request(
            method=method,
            url=upstream_url,
            headers={k: v for k, v in headers if k.lower() != 'host'},
            data=data,
            allow_redirects=False,
            timeout=300  # 5 minutes for model operations
        )
        
        # Parse response
        response_data = None
        try:
            response_data = upstream_response.json()
        except:
            response_data = upstream_response.text
        
        # Add response attributes
        current_span.set_attribute("http.status_code", upstream_response.status_code)
        
        # Extract response content
        if response_data and isinstance(response_data, dict):
            # For chat API
            if "message" in response_data:
                message = response_data["message"]
                if "content" in message:
                    response_text = message["content"]
                    current_span.set_attribute("llm.responses", response_text[:1000])
                    current_span.set_attribute("llm.response_length", len(response_text))
                    print(f"[PROXY] Response: {response_text[:100]}...")
            
            # For generate API
            elif "response" in response_data:
                response_text = response_data["response"]
                current_span.set_attribute("llm.responses", response_text[:1000])
                current_span.set_attribute("llm.response_length", len(response_text))
                print(f"[PROXY] Response: {response_text[:100]}...")
        
        print(f"[PROXY] Status: {upstream_response.status_code}")
        
        # Return response
        return Response(
            upstream_response.content,
            status=upstream_response.status_code,
            headers=dict(upstream_response.headers)
        )
        
    except Exception as e:
        current_span.set_attribute("error", True)
        current_span.set_attribute("error.message", str(e))
        current_span.record_exception(e)
        print(f"[PROXY ERROR] {str(e)}")
        raise


@workflow(name="ollama_proxy")
@app.route('/', defaults={'path': ''}, methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH'])
def proxy(path):
    """
    Main proxy endpoint. The @workflow decorator creates a parent span for the entire request.
    """
    try:
        return proxy_ollama_request(
            method=request.method,
            path=path,
            headers=request.headers,
            data=request.data,
            query_string=request.query_string
        )
    except Exception as e:
        return {"error": str(e)}, 500


if __name__ == "__main__":
    port = int(os.getenv("PORT", "11434"))
    print(f"\nStarting TraceLoop Sidecar on port {port}...")
    print(f"Proxying to: {OLLAMA_UPSTREAM}")
    print(f"Using OpenLLMetry for automatic LLM tracing")
    print("=" * 70 + "\n")
    
    app.run(host='0.0.0.0', port=port, debug=False)

# Made with Bob
