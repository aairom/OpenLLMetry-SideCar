# Quick Reference Guide

Fast access to URLs, commands, and troubleshooting for OpenLLMetry SideCar.

## 🌐 Access URLs

### Docker Compose Deployment

| Service | URL | Purpose |
|---------|-----|---------|
| **Jaeger UI** | http://localhost:16686 | View traces and LLM interactions |
| **Application API** | http://localhost:8080 | Send chat requests |
| **Ollama API** | http://localhost:11434 | Direct LLM access (bypasses sidecar) |

### Kubernetes Deployment

| Service | Access Method | URL |
|---------|---------------|-----|
| **Jaeger UI** | NodePort | http://\<minikube-ip\>:30686 |
| **Jaeger UI** | Port Forward | `kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686`<br/>Then: http://localhost:16686 |
| **Application API** | Port Forward | `kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080`<br/>Then: http://localhost:8080 |

**Get Minikube IP:**
```bash
minikube ip
```

---

## 🚀 Quick Start Commands

### Start Services
```bash
./start-all.sh
```
Interactive menu to choose Docker Compose or Kubernetes deployment.

### Stop Services
```bash
./stop-all.sh
```
Interactive menu to stop deployments.

### View Logs
```bash
./view-logs.sh
```
Interactive menu to view and manage logs.

---

## 🧪 Testing the Application

### Health Check
```bash
curl http://localhost:8080/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "model": "granite3:latest",
  "ollama_host": "http://localhost:11434",
  "log_file": "/app/logs/ollama_app_20260102_091234.log"
}
```

### Single Chat Request
```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry?"}'
```

**Expected Response:**
```json
{
  "prompt": "What is OpenTelemetry?",
  "response": "OpenTelemetry is an open-source observability framework...",
  "model": "granite3:latest",
  "duration_seconds": 2.34,
  "request_id": "20260102_091234_567890"
}
```

### Batch Requests
```bash
curl -X POST http://localhost:8080/batch \
  -H "Content-Type: application/json" \
  -d '{
    "prompts": [
      "What is distributed tracing?",
      "What is a sidecar pattern?",
      "What is Kubernetes?"
    ]
  }'
```

### Multiple Test Requests
```bash
# Generate multiple traces
for i in {1..5}; do
  curl -X POST http://localhost:8080/chat \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"Tell me about number $i\"}"
  sleep 2
done
```

---

## 📊 Viewing Traces in Jaeger

1. **Open Jaeger UI**: http://localhost:16686
2. **Select Service**: Choose `ollama-simple-app` from dropdown
3. **Click**: "Find Traces" button
4. **Inspect Trace**: Click on any trace to see details

### What to Look For

Each trace should show:
- ✅ `llm.model`: granite3:latest
- ✅ `llm.prompt`: User's question
- ✅ `llm.response`: Model's answer
- ✅ `llm.operation`: chat or generate
- ✅ `http.status_code`: 200
- ✅ `http.response_time_ms`: Duration
- ✅ `service.name`: ollama-simple-app

---

## 📋 Common Commands

### Docker Compose

```bash
# View all logs
docker-compose logs -f

# View specific service
docker-compose logs -f ollama-simple-app
docker-compose logs -f traceloop-sidecar
docker-compose logs -f otel-collector

# Check service status
docker-compose ps

# Restart a service
docker-compose restart ollama-simple-app

# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
```

### Kubernetes

```bash
# Check pod status
kubectl get pods -n openllmetry-demo

# Watch pod status
kubectl get pods -n openllmetry-demo -w

# View logs
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f
kubectl logs -n openllmetry-demo -l app=otel-collector -f

# Describe pod (for troubleshooting)
kubectl describe pod -n openllmetry-demo <pod-name>

# Execute command in pod
kubectl exec -n openllmetry-demo <pod-name> -c ollama-simple-app -- env

# Port forward services
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080

# Delete namespace (cleanup)
kubectl delete namespace openllmetry-demo
```

---

## 🔍 Log Management

### View Live Logs
```bash
# Interactive log viewer
./view-logs.sh

# Or directly
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f
docker-compose logs -f ollama-simple-app
```

### Copy Logs from Container
```bash
# Kubernetes
kubectl cp -n openllmetry-demo <pod-name>:/app/logs ./logs -c ollama-simple-app

# Docker Compose
docker cp ollama-simple-app:/app/logs ./logs
```

### View Local Log Files
```bash
# List log files
ls -lh logs/

# View specific log
less logs/ollama_app_20260102_091234.log

# Tail log file
tail -f logs/ollama_app_20260102_091234.log

# Search logs
grep "ERROR" logs/*.log
grep "request_id" logs/*.log
```

---

## 🐛 Troubleshooting

### No Traces in Jaeger

**Check 1: Is sidecar running?**
```bash
# Docker Compose
docker-compose ps traceloop-sidecar
docker-compose logs traceloop-sidecar

# Kubernetes
kubectl get pods -n openllmetry-demo
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar
```

**Check 2: Is app pointing to sidecar?**
```bash
# Docker Compose
docker-compose exec ollama-simple-app env | grep OLLAMA_HOST
# Should show: http://traceloop-sidecar:11434

# Kubernetes
kubectl exec -n openllmetry-demo <pod-name> -c ollama-simple-app -- env | grep OLLAMA_HOST
# Should show: http://localhost:11434
```

**Check 3: Is collector receiving traces?**
```bash
# Docker Compose
docker-compose logs otel-collector | grep -i "trace"

# Kubernetes
kubectl logs -n openllmetry-demo -l app=otel-collector | grep -i "trace"
```

### Application Not Responding

**Check 1: Is application running?**
```bash
# Docker Compose
docker-compose ps ollama-simple-app

# Kubernetes
kubectl get pods -n openllmetry-demo -l app=ollama-simple-app
```

**Check 2: Check application logs**
```bash
# Docker Compose
docker-compose logs ollama-simple-app --tail=100

# Kubernetes
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app --tail=100
```

**Check 3: Is model downloaded?**
```bash
# Docker Compose
docker-compose exec ollama ollama list

# Kubernetes
kubectl exec -n openllmetry-demo deployment/ollama -- ollama list
```

### Slow Responses

**Check resource usage:**
```bash
# Docker Compose
docker stats

# Kubernetes
kubectl top pods -n openllmetry-demo
```

**Check if model is loaded:**
```bash
# Docker Compose
docker-compose exec ollama ollama ps

# Kubernetes
kubectl exec -n openllmetry-demo deployment/ollama -- ollama ps
```

---

## 📖 Documentation Links

- **[README.md](README.md)** - Project overview and architecture
- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute quick start
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Detailed deployment guide with diagrams
- **[TESTING.md](TESTING.md)** - Comprehensive testing guide
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture details

---

## 🎯 Common Tasks

### Change LLM Model

**Docker Compose:**
Edit `docker-compose/docker-compose.yaml`:
```yaml
environment:
  - OLLAMA_MODEL=llama2:latest
```

**Kubernetes:**
Edit `k8s/05-ollama-simple-app.yaml`:
```yaml
env:
- name: OLLAMA_MODEL
  value: "llama2:latest"
```

Then restart:
```bash
docker-compose restart ollama-simple-app
kubectl rollout restart deployment/ollama-simple-app -n openllmetry-demo
```

### Enable Debug Logging

**Docker Compose:**
Edit `docker-compose/docker-compose.yaml`:
```yaml
environment:
  - LOG_LEVEL=DEBUG
```

**Kubernetes:**
Edit `k8s/05-ollama-simple-app.yaml`:
```yaml
env:
- name: LOG_LEVEL
  value: "DEBUG"
```

### Scale Application (Kubernetes)

```bash
# Scale to 3 replicas
kubectl scale deployment/ollama-simple-app -n openllmetry-demo --replicas=3

# Check status
kubectl get pods -n openllmetry-demo -l app=ollama-simple-app
```

---

## 💡 Tips

1. **Always check logs first** when troubleshooting - use `./view-logs.sh`
2. **Wait for model download** - First startup takes 5-10 minutes
3. **Use port-forward** for Kubernetes - More reliable than NodePort
4. **Check Jaeger regularly** - Traces appear within seconds of requests
5. **Monitor resources** - Ollama needs 2-4GB RAM depending on model
6. **Use request IDs** - Track specific requests through logs and traces

---

## 🆘 Getting Help

If you encounter issues:

1. Check this quick reference
2. Review [TESTING.md](TESTING.md) for detailed troubleshooting
3. Check logs with `./view-logs.sh`
4. Review [DEPLOYMENT.md](DEPLOYMENT.md) for deployment details
5. Check pod/container status and events

---

**Last Updated**: 2026-01-02