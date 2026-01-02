FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Create logs directory
RUN mkdir -p /app/logs

# Set environment variables with defaults
ENV OLLAMA_HOST=http://ollama:11434
ENV OLLAMA_MODEL=granite3:latest
ENV PORT=8080
ENV RUN_SAMPLES=true
ENV LOG_LEVEL=INFO

# Expose the Flask port
EXPOSE 8080

# Run the application
CMD ["python", "app.py"]