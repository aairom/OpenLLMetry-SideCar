FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Set environment variables with defaults
ENV OTEL_SERVICE_NAME=ollama-app
ENV OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
ENV OLLAMA_HOST=http://ollama:11434
ENV OLLAMA_MODEL=granite3:latest

# Run the application
CMD ["python", "app.py"]