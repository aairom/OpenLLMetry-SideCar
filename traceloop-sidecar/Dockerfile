FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY proxy.py .

# Set environment variables with defaults
ENV OLLAMA_UPSTREAM=http://ollama:11434
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
ENV OTEL_SERVICE_NAME=traceloop-sidecar
ENV TRACED_SERVICE_NAME=ollama-app
ENV PORT=11434

# Expose the proxy port (same as Ollama for transparent proxying)
EXPOSE 11434

# Run the proxy
CMD ["python", "proxy.py"]