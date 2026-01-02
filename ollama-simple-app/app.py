#!/usr/bin/env python3
"""
Simple Ollama Application - No Tracing Code
This application uses Ollama for LLM inference without any built-in tracing.
Tracing will be handled by the TraceLoop sidecar.
"""
import os
import sys
import time
import logging
from datetime import datetime
from pathlib import Path
import ollama
from flask import Flask, request, jsonify

app = Flask(__name__)

# Configuration
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://ollama:11434")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "granite3:latest")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")

# Setup logging directory
LOG_DIR = Path("./logs")
LOG_DIR.mkdir(exist_ok=True)

# Create timestamped log file
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
log_file = LOG_DIR / f"ollama_app_{timestamp}.log"

# Configure logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper()),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

# Log startup information
logger.info("=" * 60)
logger.info("Simple Ollama Application Starting")
logger.info("=" * 60)
logger.info(f"Ollama Host: {OLLAMA_HOST}")
logger.info(f"Model: {OLLAMA_MODEL}")
logger.info(f"Log Level: {LOG_LEVEL}")
logger.info(f"Log File: {log_file}")
logger.info("=" * 60)


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    logger.debug("Health check requested")
    return jsonify({
        "status": "healthy",
        "model": OLLAMA_MODEL,
        "ollama_host": OLLAMA_HOST,
        "log_file": str(log_file)
    }), 200


@app.route('/chat', methods=['POST'])
def chat():
    """
    Chat endpoint - accepts a prompt and returns a response
    
    Request body:
    {
        "prompt": "Your question here",
        "model": "optional-model-override"
    }
    """
    request_id = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    logger.info(f"[{request_id}] Chat request received")
    
    try:
        data = request.get_json()
        
        if not data or 'prompt' not in data:
            logger.warning(f"[{request_id}] Missing 'prompt' in request body")
            return jsonify({"error": "Missing 'prompt' in request body"}), 400
        
        prompt = data['prompt']
        model = data.get('model', OLLAMA_MODEL)
        
        logger.info(f"[{request_id}] Prompt: {prompt[:100]}{'...' if len(prompt) > 100 else ''}")
        logger.info(f"[{request_id}] Model: {model}")
        logger.info(f"[{request_id}] Ollama Host: {OLLAMA_HOST}")
        
        # Create Ollama client
        try:
            client = ollama.Client(host=OLLAMA_HOST)
            logger.debug(f"[{request_id}] Ollama client created successfully")
        except Exception as e:
            logger.error(f"[{request_id}] Failed to create Ollama client: {e}")
            raise
        
        # Send the prompt
        start_time = time.time()
        logger.info(f"[{request_id}] Sending request to Ollama...")
        
        try:
            response = client.chat(
                model=model,
                messages=[
                    {
                        'role': 'user',
                        'content': prompt,
                    },
                ],
            )
            logger.debug(f"[{request_id}] Received response from Ollama")
        except Exception as e:
            logger.error(f"[{request_id}] Ollama request failed: {e}")
            raise
        
        response_text = response['message']['content']
        duration = time.time() - start_time
        
        logger.info(f"[{request_id}] Response received in {duration:.2f}s")
        logger.info(f"[{request_id}] Response length: {len(response_text)} characters")
        logger.debug(f"[{request_id}] Response preview: {response_text[:100]}...")
        
        return jsonify({
            "prompt": prompt,
            "response": response_text,
            "model": model,
            "duration_seconds": duration,
            "request_id": request_id
        }), 200
        
    except Exception as e:
        logger.error(f"[{request_id}] Error processing chat request: {str(e)}", exc_info=True)
        return jsonify({
            "error": str(e),
            "request_id": request_id
        }), 500


@app.route('/batch', methods=['POST'])
def batch_chat():
    """
    Batch chat endpoint - accepts multiple prompts
    
    Request body:
    {
        "prompts": ["Question 1", "Question 2", ...],
        "model": "optional-model-override"
    }
    """
    request_id = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    logger.info(f"[{request_id}] Batch request received")
    
    try:
        data = request.get_json()
        
        if not data or 'prompts' not in data:
            logger.warning(f"[{request_id}] Missing 'prompts' in request body")
            return jsonify({"error": "Missing 'prompts' in request body"}), 400
        
        prompts = data['prompts']
        model = data.get('model', OLLAMA_MODEL)
        
        if not isinstance(prompts, list):
            logger.warning(f"[{request_id}] 'prompts' is not a list")
            return jsonify({"error": "'prompts' must be a list"}), 400
        
        logger.info(f"[{request_id}] Processing {len(prompts)} prompts")
        logger.info(f"[{request_id}] Model: {model}")
        
        # Create Ollama client
        try:
            client = ollama.Client(host=OLLAMA_HOST)
            logger.debug(f"[{request_id}] Ollama client created successfully")
        except Exception as e:
            logger.error(f"[{request_id}] Failed to create Ollama client: {e}")
            raise
        
        results = []
        total_start = time.time()
        
        for i, prompt in enumerate(prompts, 1):
            logger.info(f"[{request_id}] Batch {i}/{len(prompts)} - Prompt: {prompt[:50]}...")
            
            try:
                start_time = time.time()
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
                duration = time.time() - start_time
                
                results.append({
                    "prompt": prompt,
                    "response": response_text,
                    "duration_seconds": duration
                })
                
                logger.info(f"[{request_id}] Batch {i}/{len(prompts)} completed in {duration:.2f}s")
                
            except Exception as e:
                logger.error(f"[{request_id}] Batch {i}/{len(prompts)} failed: {e}")
                results.append({
                    "prompt": prompt,
                    "error": str(e),
                    "duration_seconds": 0
                })
        
        total_duration = time.time() - total_start
        logger.info(f"[{request_id}] Batch request completed in {total_duration:.2f}s")
        
        return jsonify({
            "results": results,
            "model": model,
            "total_duration_seconds": total_duration,
            "count": len(results),
            "request_id": request_id
        }), 200
        
    except Exception as e:
        logger.error(f"[{request_id}] Error processing batch request: {str(e)}", exc_info=True)
        return jsonify({
            "error": str(e),
            "request_id": request_id
        }), 500


def run_sample_queries():
    """Run some sample queries on startup"""
    logger.info("=" * 60)
    logger.info("Running sample queries...")
    logger.info("=" * 60)
    
    sample_prompts = [
        "What is OpenTelemetry?",
        "Explain distributed tracing in one sentence.",
        "What are the benefits of observability?",
    ]
    
    try:
        client = ollama.Client(host=OLLAMA_HOST)
        logger.info(f"Connected to Ollama at {OLLAMA_HOST}")
    except Exception as e:
        logger.error(f"Failed to connect to Ollama: {e}")
        return
    
    for i, prompt in enumerate(sample_prompts, 1):
        logger.info(f"Sample {i}/{len(sample_prompts)} - Prompt: {prompt}")
        try:
            start_time = time.time()
            response = client.chat(
                model=OLLAMA_MODEL,
                messages=[{'role': 'user', 'content': prompt}],
            )
            duration = time.time() - start_time
            response_text = response['message']['content']
            logger.info(f"Sample {i}/{len(sample_prompts)} - Completed in {duration:.2f}s")
            logger.debug(f"Sample {i}/{len(sample_prompts)} - Response: {response_text[:100]}...")
        except Exception as e:
            logger.error(f"Sample {i}/{len(sample_prompts)} - Error: {e}", exc_info=True)
        
        time.sleep(1)
    
    logger.info("=" * 60)
    logger.info("Sample queries completed!")
    logger.info("=" * 60)


if __name__ == "__main__":
    # Run sample queries if in standalone mode
    if os.getenv("RUN_SAMPLES", "true").lower() == "true":
        try:
            run_sample_queries()
        except Exception as e:
            logger.error(f"Sample queries failed: {e}", exc_info=True)
    
    # Start Flask server
    port = int(os.getenv("PORT", "8080"))
    logger.info(f"Starting Flask server on port {port}...")
    logger.info(f"Logs are being written to: {log_file}")
    app.run(host='0.0.0.0', port=port, debug=False)

# Made with Bob
