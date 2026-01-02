# Quick Start Guide

Get up and running with the OpenLLMetry Sidecar in 5 minutes!

> **📖 For comprehensive deployment instructions with mermaid diagrams and troubleshooting, see [DEPLOYMENT.md](DEPLOYMENT.md)**

## What You'll Get

A complete tracing setup where:
- ✅ Your application has **ZERO tracing code**
- ✅ TraceLoop sidecar **automatically traces** all LLM calls
- ✅ Traces appear in Jaeger with prompts, responses, and timing

## Option 1: Docker Compose (Recommended)

### Prerequisites
- Docker and Docker Compose installed
- At least 4GB RAM available

### Steps

1. **Start everything:**
   ```bash
   cd docker-compose
   docker-compose up --build
   ```
   
   Wait 5-10 minutes for Ollama to download the Granite3 model (~2GB).

2. **View traces:**
   
   Open: http://localhost:16686
   
   - Service dropdown: Select **`ollama-simple-app`**
   - Click "Find Traces"
   - Click any trace to see LLM details

3. **Test the API:**
   ```bash
   curl -X POST http://localhost:8080/chat \
     -H "Content-Type: application/json" \
     -d '{"prompt": "Explain distributed tracing"}'
   ```

4. **Watch it work:**
   ```bash
   # Application logs (no tracing code!)
   docker-compose logs -f ollama-simple-app
   
   # Sidecar logs (shows tracing magic)
   docker-compose logs -f traceloop-sidecar
   ```

5. **Stop:**
   ```bash
   docker-compose down
   ```

## Option 2: Kubernetes (Minikube)

### Prerequisites
- Minikube and kubectl installed
- At least 6GB RAM available

### Steps

1. **One command deploy:**
   ```bash
   ./deploy-minikube.sh
   ```

2. **Access Jaeger:**
   ```bash
   # Get Minikube IP
   minikube ip
   
   # Visit: http://<minikube-ip>:30686
   
   # Or use port-forward:
   kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
   # Then: http://localhost:16686
   ```

3. **View logs:**
   ```bash
   # Application
   kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f
   
   # Sidecar
   kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f
   ```

4. **Cleanup:**
   ```bash
   ./cleanup-minikube.sh
   ```

## What to Look For in Jaeger

1. **Service**: Select `ollama-simple-app` from dropdown
2. **Traces**: Each trace represents one LLM interaction
3. **Span Details**: Click a trace to see:
   - `llm.model`: Model used (granite3:latest)
   - `llm.prompt`: Question asked
   - `llm.response`: Model's answer
   - `llm.operation`: Type (chat, generate, etc.)
   - Duration and timing

## The Magic: How It Works

```
Your App Code:
  client = ollama.Client(host="http://localhost:11434")
  response = client.chat(...)  # No tracing code!

What Actually Happens:
  App → TraceLoop Sidecar (adds tracing) → Ollama
  
Traces Flow:
  Sidecar → OTel Collector → Jaeger
```

## Key Files

- [`ollama-simple-app/app.py`](ollama-simple-app/app.py) - App with NO tracing code
- [`traceloop-sidecar/proxy.py`](traceloop-sidecar/proxy.py) - Transparent tracing proxy
- [`docker-compose/docker-compose.yaml`](docker-compose/docker-compose.yaml) - Local setup
- [`k8s/05-ollama-simple-app.yaml`](k8s/05-ollama-simple-app.yaml) - Sidecar deployment

## Troubleshooting

### "Model not found"
The model is downloading. Wait 5-10 minutes and check:
```bash
docker-compose logs ollama
```

### No traces in Jaeger
1. Check sidecar is running:
   ```bash
   docker-compose ps traceloop-sidecar
   ```

2. Verify app uses sidecar:
   ```bash
   docker-compose logs ollama-simple-app | grep "Ollama Host"
   # Should show: http://traceloop-sidecar:11434
   ```

### Services not starting
Ensure enough resources:
- Docker Compose: 4GB RAM minimum
- Kubernetes: 6GB RAM minimum

## Next Steps

1. **Read [DEPLOYMENT.md](DEPLOYMENT.md)** for detailed deployment with mermaid diagrams
2. **Read the full [README.md](README.md)** for architecture details
3. **Inspect the sidecar code** at [`traceloop-sidecar/proxy.py`](traceloop-sidecar/proxy.py)
4. **Add sidecar to your own app** - see README section "Adding Sidecar to Your Own Application"
5. **Try different models** by changing `OLLAMA_MODEL` environment variable

## Architecture Summary

```
┌─────────────────────────────────────┐
│         Application Pod              │
│                                      │
│  ┌──────────────┐  ┌──────────────┐ │
│  │ Simple App   │→ │  TraceLoop   │ │
│  │ (No tracing!)│  │   Sidecar    │ │
│  └──────────────┘  └──────┬───────┘ │
└────────────────────────────┼─────────┘
                             ↓
                        ┌─────────┐
                        │ Ollama  │
                        └────┬────┘
                             ↓
                        ┌─────────┐
                        │ Jaeger  │
                        └─────────┘
```

**The application never knows it's being traced!**