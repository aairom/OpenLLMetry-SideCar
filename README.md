# OpenLLMetry SideCar - Independent Tracing for LLM Applications

This project demonstrates a **sidecar pattern** for adding distributed tracing to LLM applications using [OpenLLMetry](https://github.com/traceloop/openllmetry). The key innovation is that the **application code requires NO tracing instrumentation** - all tracing is handled by an independent TraceLoop sidecar proxy.

## 📚 Documentation

- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - ⚡ Fast access to URLs, commands, and troubleshooting
- **[QUICKSTART.md](QUICKSTART.md)** - Get started in 5 minutes
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide with step-by-step instructions and mermaid diagrams
- **[TESTING.md](TESTING.md)** - Comprehensive testing guide with examples and troubleshooting
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture and design decisions

## Key Architecture Principle

**Separation of Concerns**: The application and tracing infrastructure are completely independent:

1. **Ollama Simple App** - Pure business logic, no tracing code
2. **TraceLoop Sidecar** - Transparent proxy that adds OpenTelemetry tracing
3. **OpenTelemetry Collector** - Processes and routes traces
4. **Jaeger** - Visualizes traces

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Pod/Container                     │
│                                                                  │
│  ┌──────────────────┐         ┌─────────────────────┐          │
│  │  Simple Ollama   │────────▶│  TraceLoop Sidecar  │          │
│  │  Application     │ localhost│  (Tracing Proxy)   │          │
│  │  (No tracing!)   │  :11434 │                     │          │
│  └──────────────────┘         └──────────┬──────────┘          │
│                                           │                      │
└───────────────────────────────────────────┼──────────────────────┘
                                            │
                                            │ Proxied + Traced
                                            ▼
                                   ┌─────────────────┐
                                   │     Ollama      │
                                   │  (LLM Engine)   │
                                   └─────────────────┘
                                            
                                            │ OTLP/gRPC
                                            ▼
                                   ┌─────────────────┐
                                   │ OTel Collector  │
                                   └────────┬────────┘
                                            │
                                            ▼
                                   ┌─────────────────┐
                                   │     Jaeger      │
                                   │ (Visualization) │
                                   └─────────────────┘
```

## Project Structure

```
.
├── ollama-simple-app/          # Application WITHOUT tracing code
│   ├── app.py                  # Pure Flask app using Ollama
│   ├── requirements.txt        # No OpenTelemetry dependencies!
│   └── Dockerfile
├── traceloop-sidecar/          # Independent tracing sidecar
│   ├── proxy.py                # Transparent tracing proxy
│   ├── requirements.txt        # OpenTelemetry dependencies here
│   └── Dockerfile
├── ollama-app/                 # (Optional) App with built-in tracing
│   └── ...                     # For comparison purposes
├── collector/                  # OpenTelemetry Collector
│   ├── otel-collector-config.yaml
│   └── Dockerfile
├── k8s/                        # Kubernetes manifests
│   ├── 00-namespace.yaml
│   ├── 01-otel-collector.yaml
│   ├── 02-ollama.yaml
│   ├── 04-jaeger.yaml
│   └── 05-ollama-simple-app.yaml  # Sidecar deployment
├── docker-compose/
│   └── docker-compose.yaml
├── start-all.sh                # Utility: Start all services
├── stop-all.sh                 # Utility: Stop all services
├── push-to-github.sh           # Utility: Push to GitHub
└── README.md
```

## Utility Scripts

Four convenience scripts are provided for easy project management:

### 🚀 start-all.sh
Interactive script to start services in either Docker Compose or Kubernetes:
```bash
./start-all.sh
```
- Detects available environments (Docker/Kubernetes)
- Provides menu-driven deployment
- Builds images and starts all services
- Shows access information and useful commands

### 🛑 stop-all.sh
Interactive script to stop running services:
```bash
./stop-all.sh
```
- Detects running deployments
- Allows selective or complete shutdown
- Option to preserve or remove volumes
- Option to stop Minikube cluster

### 📋 view-logs.sh
Interactive script to view and manage application logs:
```bash
./view-logs.sh
```
- View live logs from application, sidecar, or collector
- View timestamped log files from ./logs directory
- Copy logs from containers to local machine
- Support for both Docker Compose and Kubernetes

### 📤 push-to-github.sh
Interactive script to commit and push changes to GitHub:
```bash
./push-to-github.sh
```
- Shows repository status
- Stages and commits changes
- Configures remote if needed
- Pushes to GitHub with safety checks

## How It Works

### The Sidecar Pattern

1. **Application makes Ollama API calls** to `localhost:11434`
2. **TraceLoop Sidecar intercepts** the traffic (running on same pod/network)
3. **Sidecar adds OpenTelemetry spans** with LLM-specific attributes
4. **Sidecar forwards request** to actual Ollama service
5. **Response flows back** through sidecar with complete trace context
6. **Traces exported** to OpenTelemetry Collector → Jaeger

### Benefits

✅ **Zero code changes** - Application remains clean and focused  
✅ **Language agnostic** - Works with any language/framework  
✅ **Centralized tracing logic** - Update tracing without touching apps  
✅ **Easy to enable/disable** - Remove sidecar to disable tracing  
✅ **Consistent instrumentation** - Same tracing for all apps  

## Quick Start with Docker Compose

> **📖 For detailed deployment instructions with troubleshooting, see [DEPLOYMENT.md](DEPLOYMENT.md)**

### Quick Start (Recommended)

```bash
# Interactive deployment script
./start-all.sh
```

### Manual Start

```bash
cd docker-compose
docker-compose up --build
```

This starts:
- Jaeger (trace visualization)
- OpenTelemetry Collector
- Ollama (downloads Granite3 model - takes 5-10 minutes)
- **TraceLoop Sidecar** (tracing proxy)
- **Simple Ollama App** (no tracing code)

### 2. View Traces

Open Jaeger UI: http://localhost:16686

- Select service: **`ollama-simple-app`**
- Click "Find Traces"
- Explore traces showing LLM calls with prompts and responses

### 3. Test the API

The simple app exposes a REST API:

```bash
# Single chat request
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry?"}'

# Batch requests
curl -X POST http://localhost:8080/batch \
  -H "Content-Type: application/json" \
  -d '{"prompts": ["Question 1", "Question 2"]}'
```

### 4. Monitor Logs

```bash
# Application logs (no tracing code!)
docker-compose logs -f ollama-simple-app

# Sidecar logs (shows tracing activity)
docker-compose logs -f traceloop-sidecar

# Collector logs
docker-compose logs -f otel-collector
```

### 5. Stop Services

```bash
# Interactive stop script (recommended)
./stop-all.sh

# Or manually
cd docker-compose
docker-compose down

# Remove volumes (including downloaded models)
docker-compose down -v
```

## Deployment on Kubernetes (Minikube)

> **📖 For detailed Kubernetes deployment with diagrams and troubleshooting, see [DEPLOYMENT.md](DEPLOYMENT.md)**

### Quick Start (Recommended)

```bash
# Interactive deployment script
./start-all.sh
```

### Alternative: Automated Script

```bash
./deploy-minikube.sh
```

This automated script:
- Starts Minikube (if needed)
- Builds all container images
- Deploys all services
- Waits for pods to be ready

### 2. Manual Deployment

```bash
# Start Minikube
minikube start --memory=6144 --cpus=4

# Set Docker environment
eval $(minikube docker-env)

# Build images
cd traceloop-sidecar && docker build -t traceloop-sidecar:latest . && cd ..
cd ollama-simple-app && docker build -t ollama-simple-app:latest . && cd ..

# Deploy
kubectl apply -f k8s/
```

### 3. Access Jaeger UI

```bash
# Get Minikube IP
minikube ip

# Access at: http://<minikube-ip>:30686

# Or use port-forward
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
# Then: http://localhost:16686
```

### 4. View Logs

```bash
# Application logs
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f

# Sidecar logs
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f

# Collector logs
kubectl logs -n openllmetry-demo -l app=otel-collector -f
```

### 5. Cleanup

```bash
# Interactive cleanup (recommended)
./stop-all.sh

# Or use cleanup script
./cleanup-minikube.sh
```

## Understanding the Sidecar

### TraceLoop Sidecar Features

The sidecar ([`traceloop-sidecar/proxy.py`](traceloop-sidecar/proxy.py)) automatically:

1. **Intercepts HTTP traffic** to Ollama API
2. **Creates OpenTelemetry spans** for each request
3. **Extracts LLM information**:
   - Model name
   - Prompts
   - Responses
   - Operation type (chat, generate, etc.)
4. **Adds span attributes**:
   - `llm.model`: Model identifier
   - `llm.prompt`: User prompt
   - `llm.response`: Model response
   - `llm.operation`: Type of operation
   - `http.status_code`: Response status
   - `http.response_time_ms`: Duration
5. **Forwards to upstream** Ollama service
6. **Exports traces** to OpenTelemetry Collector

### Application Code Comparison

**Without Sidecar (Traditional):**
```python
from traceloop.sdk import Traceloop
import ollama

Traceloop.init()  # Tracing code in app!

client = ollama.Client()
response = client.chat(...)
```

**With Sidecar (This Project):**
```python
import ollama

# No tracing code needed!
client = ollama.Client(host="http://localhost:11434")  # Points to sidecar
response = client.chat(...)
```

The application is **completely unaware** of tracing!

## Configuration

### Environment Variables

#### TraceLoop Sidecar
- `OLLAMA_UPSTREAM`: Upstream Ollama endpoint (default: `http://ollama:11434`)
- `OTEL_EXPORTER_OTLP_ENDPOINT`: Collector endpoint (default: `http://otel-collector:4317`)
- `OTEL_SERVICE_NAME`: Sidecar service name (default: `traceloop-sidecar`)
- `TRACED_SERVICE_NAME`: Application service name (default: `ollama-simple-app`)
- `PORT`: Proxy listen port (default: `11434`)

#### Simple Ollama App
- `OLLAMA_HOST`: Ollama endpoint (default: `http://localhost:11434` - points to sidecar)
- `OLLAMA_MODEL`: Model to use (default: `granite3:latest`)
- `PORT`: Flask server port (default: `8080`)
- `RUN_SAMPLES`: Run sample queries on startup (default: `true`)

## Trace Attributes

The sidecar adds these attributes to spans:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `llm.system` | LLM system | `ollama` |
| `llm.model` | Model name | `granite3:latest` |
| `llm.operation` | Operation type | `chat`, `generate`, `pull` |
| `llm.prompt` | User prompt | `What is OpenTelemetry?` |
| `llm.response` | Model response | `OpenTelemetry is...` |
| `llm.response_length` | Response length | `245` |
| `http.method` | HTTP method | `POST` |
| `http.url` | Full URL | `http://ollama:11434/api/chat` |
| `http.status_code` | Response status | `200` |
| `http.response_time_ms` | Duration | `1234.56` |
| `service.name` | Service name | `ollama-simple-app` |

## Using Different Models

Change the model without code changes:

**Docker Compose:**
```yaml
environment:
  - OLLAMA_MODEL=llama2:latest
```

**Kubernetes:**
```yaml
env:
- name: OLLAMA_MODEL
  value: "llama2:latest"
```

## Adding Sidecar to Your Own Application

To add tracing to your existing Ollama application:

### Docker Compose

```yaml
your-app:
  image: your-app:latest
  environment:
    - OLLAMA_HOST=http://localhost:11434  # Point to sidecar
  depends_on:
    - traceloop-sidecar

traceloop-sidecar:
  image: traceloop-sidecar:latest
  environment:
    - OLLAMA_UPSTREAM=http://ollama:11434
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
    - TRACED_SERVICE_NAME=your-app
  network_mode: "service:your-app"  # Share network namespace
```

### Kubernetes

```yaml
containers:
- name: your-app
  image: your-app:latest
  env:
  - name: OLLAMA_HOST
    value: "http://localhost:11434"

- name: traceloop-sidecar
  image: traceloop-sidecar:latest
  env:
  - name: OLLAMA_UPSTREAM
    value: "http://ollama:11434"
  - name: TRACED_SERVICE_NAME
    value: "your-app"
```

## Troubleshooting

### No Traces Appearing

1. **Check sidecar is running:**
   ```bash
   # Docker Compose
   docker-compose logs traceloop-sidecar
   
   # Kubernetes
   kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar
   ```

2. **Verify app points to sidecar:**
   - Should use `localhost:11434` or `http://traceloop-sidecar:11434`
   - NOT directly to Ollama

3. **Check collector connectivity:**
   ```bash
   kubectl logs -n openllmetry-demo -l app=otel-collector
   ```

### Application Can't Reach Ollama

- Ensure `OLLAMA_HOST` points to sidecar, not Ollama directly
- In Kubernetes: Use `localhost:11434` (sidecar in same pod)
- In Docker Compose: Use `http://traceloop-sidecar:11434`

### Model Not Found

```bash
# Pull model manually
docker-compose exec ollama ollama pull granite3:latest

# Or in Kubernetes
kubectl exec -n openllmetry-demo deployment/ollama -- ollama pull granite3:latest
```

## Comparison: Sidecar vs Built-in Tracing

This project includes both approaches for comparison:

| Aspect | Sidecar (This Project) | Built-in Tracing |
|--------|------------------------|------------------|
| Code changes | ❌ None | ✅ Required |
| Dependencies | ❌ None in app | ✅ OpenTelemetry libs |
| Language support | ✅ Any | ⚠️ Language-specific |
| Maintenance | ✅ Centralized | ⚠️ Per application |
| Performance | ⚠️ Extra hop | ✅ Direct |
| Flexibility | ⚠️ HTTP only | ✅ Any protocol |

### Running Built-in Tracing Version

```bash
docker-compose --profile with-instrumented up
```

This starts the `ollama-app-instrumented` service with tracing code built-in.

## Resources

- [OpenLLMetry Documentation](https://www.traceloop.com/docs/openllmetry/getting-started-python)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Ollama API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [Sidecar Pattern](https://learn.microsoft.com/en-us/azure/architecture/patterns/sidecar)

## License

This project is provided as-is for demonstration purposes.