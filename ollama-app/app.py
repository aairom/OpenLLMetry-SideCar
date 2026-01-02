#!/usr/bin/env python3
"""
Sample Ollama Application with OpenLLMetry Tracing
This application demonstrates how to use Ollama with OpenTelemetry tracing
"""
import os
import time
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from traceloop.sdk import Traceloop
import ollama

# Initialize OpenTelemetry with Traceloop
def init_tracing():
    """Initialize OpenTelemetry tracing with OTLP exporter"""
    
    # Get configuration from environment variables
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317")
    service_name = os.getenv("OTEL_SERVICE_NAME", "ollama-app")
    
    print(f"Initializing tracing with endpoint: {otlp_endpoint}")
    print(f"Service name: {service_name}")
    
    # Initialize Traceloop SDK
    Traceloop.init(
        app_name=service_name,
        disable_batch=False,
        exporter_otlp_endpoint=otlp_endpoint
    )
    
    print("Tracing initialized successfully")

def chat_with_ollama(model: str, prompt: str) -> str:
    """
    Send a prompt to Ollama and get a response
    
    Args:
        model: The model to use (e.g., 'granite3:latest')
        prompt: The prompt to send to the model
        
    Returns:
        The model's response
    """
    tracer = trace.get_tracer(__name__)
    
    with tracer.start_as_current_span("ollama_chat") as span:
        span.set_attribute("llm.model", model)
        span.set_attribute("llm.prompt", prompt)
        
        try:
            # Get Ollama host from environment
            ollama_host = os.getenv("OLLAMA_HOST", "http://ollama:11434")
            
            print(f"\nSending prompt to Ollama ({model})...")
            print(f"Prompt: {prompt}")
            
            # Create Ollama client
            client = ollama.Client(host=ollama_host)
            
            # Send the prompt
            response = client.chat(
                model=model,
                messages=[
                    {
                        'role': 'user',
                        'content': prompt,
                    },
                ],
            )
            
            response_text = response['message']['content']
            
            span.set_attribute("llm.response", response_text)
            span.set_attribute("llm.response_length", len(response_text))
            
            print(f"Response: {response_text}\n")
            
            return response_text
            
        except Exception as e:
            span.set_attribute("error", True)
            span.set_attribute("error.message", str(e))
            print(f"Error: {e}")
            raise

def main():
    """Main application loop"""
    print("=" * 60)
    print("Ollama Application with OpenLLMetry Tracing")
    print("=" * 60)
    
    # Initialize tracing
    init_tracing()
    
    # Get model from environment
    model = os.getenv("OLLAMA_MODEL", "granite3:latest")
    
    # Sample prompts to demonstrate tracing
    prompts = [
        "What is OpenTelemetry?",
        "Explain distributed tracing in one sentence.",
        "What are the benefits of observability?",
    ]
    
    print(f"\nUsing model: {model}")
    print(f"Running {len(prompts)} sample queries...\n")
    
    # Run sample queries
    for i, prompt in enumerate(prompts, 1):
        print(f"Query {i}/{len(prompts)}")
        try:
            chat_with_ollama(model, prompt)
            time.sleep(2)  # Small delay between requests
        except Exception as e:
            print(f"Failed to process query: {e}")
    
    print("\n" + "=" * 60)
    print("All queries completed. Check your tracing backend for traces!")
    print("=" * 60)
    
    # Keep the application running to allow traces to be exported
    print("\nKeeping application alive for trace export...")
    time.sleep(10)

if __name__ == "__main__":
    main()

# Made with Bob
