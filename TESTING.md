# Testing Guide

Complete guide for testing the OpenLLMetry SideCar application after deployment.

## Table of Contents

- [Wait for Deployment](#wait-for-deployment)
- [Verify Services](#verify-services)
- [Test Application](#test-application)
- [Verify Tracing](#verify-tracing)
- [Performance Testing](#performance-testing)
- [Troubleshooting Tests](#troubleshooting-tests)

---

## Wait for Deployment

### Kubernetes Deployment

After running `./start-all.sh` and selecting Kubernetes, wait for the deployment to complete:

```bash
# Watch pod status (wait until all are Running)
kubectl get pods -n openllmetry-demo -w

# Expected output (after 5-10 minutes):
# NAME                                READY   STATUS    RESTARTS   AGE
# otel-collector-xxx                  1/1     Running   0          5m
# ollama-xxx                          1/1     Running   0          5m
# jaeger-xxx                          1/1     Running   0          5m
# ollama-simple-app-xxx               2/2     Running   0          3m
```

**Note**: The `ollama-simple-app` pod will take 5-10 minutes to start because it needs to download the granite3 model (~2GB).

### Docker Compose Deployment

```bash
# Check service status
docker-compose ps

# Expected output:
# NAME                    STATUS              PORTS
# jaeger                  Up                  0.0.0.0:16686->16686/tcp
# otel-collector          Up                  0.0.0.0:4317->4317/tcp
# ollama                  Up (healthy)        0.0.0.0:11434->11434/tcp
# traceloop-sidecar       Up                  0.0.0.0:11435->11434/tcp
# ollama-simple-app       Up                  0.0.0.0:8080->8080/tcp
```

---

## Verify Services

### 1. Check Pod/Container Logs

**Kubernetes:**
```bash
# Application logs (should show startup and sample queries)
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app --tail=50

# Sidecar logs (should show span creation)
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar --tail=50

# Collector logs
kubectl logs -n openllmetry-demo -l app=otel-collector --tail=50
```

**Docker Compose:**
```bash
# Application logs
docker-compose logs ollama-simple-app --tail=50

# Sidecar logs
docker-compose logs traceloop-sidecar --tail=50

# Collector logs
docker-compose logs otel-collector --tail=50
```

### 2. Verify Application is Running

**Kubernetes:**
```bash
# Port forward to access the application
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080

# In another terminal, test health endpoint
curl http://localhost:8080/health
```

**Docker Compose:**
```bash
# Test health endpoint
curl http://localhost:8080/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "ollama_host": "http://localhost:11434",
  "model": "granite3:latest"
}
```

### 3. Access Jaeger UI

**Kubernetes:**
```bash
# Method 1: Get Minikube IP
minikube ip
# Then visit: http://<minikube-ip>:30686

# Method 2: Port forward (recommended)
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
# Then visit: http://localhost:16686
```

**Docker Compose:**
```bash
# Visit: http://localhost:16686
```

In Jaeger UI:
1. Select service: **`ollama-simple-app`**
2. Click **"Find Traces"**
3. You should see traces from the sample queries that ran on startup

---

## Test Application

### Test 1: Single Chat Request

```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry in one sentence?"}'
```

**Expected response:**
```json
{
  "response": "OpenTelemetry is an open-source observability framework...",
  "model": "granite3:latest"
}
```

### Test 2: Batch Requests

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

**Expected response:**
```json
{
  "responses": [
    {
      "prompt": "What is distributed tracing?",
      "response": "Distributed tracing is...",
      "model": "granite3:latest"
    },
    {
      "prompt": "What is a sidecar pattern?",
      "response": "A sidecar pattern is...",
      "model": "granite3:latest"
    },
    {
      "prompt": "What is Kubernetes?",
      "response": "Kubernetes is...",
      "model": "granite3:latest"
    }
  ]
}
```

### Test 3: Multiple Sequential Requests

```bash
# Run multiple requests to generate more traces
for i in {1..5}; do
  echo "Request $i:"
  curl -X POST http://localhost:8080/chat \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"Tell me a fact about number $i\"}"
  echo -e "\n---"
  sleep 2
done
```

### Test 4: Test with Different Prompts

```bash
# Technical question
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explain the sidecar pattern in microservices"}'

# Creative question
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Write a haiku about observability"}'

# Code question
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Show me a Python hello world example"}'
```

---

## Verify Tracing

### 1. Check Traces in Jaeger

1. Open Jaeger UI: http://localhost:16686
2. Select service: **`ollama-simple-app`**
3. Click **"Find Traces"**
4. Click on any trace to inspect

### 2. Verify Span Attributes

Each trace should contain these attributes:

**Required Attributes:**
- ✅ `llm.system`: `ollama`
- ✅ `llm.model`: `granite3:latest`
- ✅ `llm.operation`: `chat` or `generate`
- ✅ `llm.prompt`: The user's question
- ✅ `llm.response`: The model's answer
- ✅ `llm.response_length`: Length of response
- ✅ `http.method`: `POST`
- ✅ `http.url`: Full URL
- ✅ `http.status_code`: `200`
- ✅ `http.response_time_ms`: Duration
- ✅ `service.name`: `ollama-simple-app`

### 3. Verify Trace Structure

```
Trace Timeline:
┌─────────────────────────────────────────────────┐
│ ollama.post.api/chat                            │
│ Duration: ~1000-3000ms                          │
│                                                 │
│ Tags:                                           │
│   llm.model: granite3:latest                    │
│   llm.prompt: "What is..."                      │
│   llm.response: "OpenTelemetry is..."           │
│   http.status_code: 200                         │
└─────────────────────────────────────────────────┘
```

### 4. Verify No Tracing Code in Application

**Kubernetes:**
```bash
# View application code
kubectl exec -n openllmetry-demo deployment/ollama-simple-app -c ollama-simple-app -- cat /app/app.py | grep -i "trace\|otel\|span"
# Should return nothing!
```

**Docker Compose:**
```bash
# View application code
docker-compose exec ollama-simple-app cat /app/app.py | grep -i "trace\|otel\|span"
# Should return nothing!
```

---

## Performance Testing

### Test 1: Response Time

```bash
# Test response time
time curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is 2+2?"}'
```

**Expected:**
- First request: 2-5 seconds (model loading)
- Subsequent requests: 1-3 seconds

### Test 2: Concurrent Requests

```bash
# Install apache bench if needed
# macOS: brew install httpd
# Linux: apt-get install apache2-utils

# Create test payload
cat > test-payload.json << EOF
{"prompt": "What is OpenTelemetry?"}
EOF

# Run 10 concurrent requests
ab -n 10 -c 2 -p test-payload.json -T application/json http://localhost:8080/chat
```

### Test 3: Sidecar Overhead

Compare response times with and without sidecar:

**With Sidecar (Current Setup):**
```bash
time curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Quick test"}'
```

**Expected Overhead:**
- Sidecar adds ~2-5ms latency
- Trace export is asynchronous (no impact on response time)

---

## Troubleshooting Tests

### Issue: No Response from Application

**Check 1: Is the application running?**
```bash
# Kubernetes
kubectl get pods -n openllmetry-demo

# Docker Compose
docker-compose ps
```

**Check 2: Are there errors in logs?**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app --tail=100

# Docker Compose
docker-compose logs ollama-simple-app --tail=100
```

**Check 3: Is the model downloaded?**
```bash
# Kubernetes
kubectl exec -n openllmetry-demo deployment/ollama -- ollama list

# Docker Compose
docker-compose exec ollama ollama list
```

### Issue: No Traces in Jaeger

**Check 1: Is sidecar running?**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar --tail=50

# Docker Compose
docker-compose logs traceloop-sidecar --tail=50
```

**Check 2: Is collector receiving traces?**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=otel-collector --tail=50 | grep -i "trace"

# Docker Compose
docker-compose logs otel-collector --tail=50 | grep -i "trace"
```

**Check 3: Is application pointing to sidecar?**
```bash
# Kubernetes
kubectl exec -n openllmetry-demo deployment/ollama-simple-app -c ollama-simple-app -- env | grep OLLAMA_HOST
# Should show: http://localhost:11434

# Docker Compose
docker-compose exec ollama-simple-app env | grep OLLAMA_HOST
# Should show: http://traceloop-sidecar:11434
```

### Issue: Slow Responses

**Check 1: Resource usage**
```bash
# Kubernetes
kubectl top pods -n openllmetry-demo

# Docker
docker stats
```

**Check 2: Is model loaded?**
```bash
# Kubernetes
kubectl exec -n openllmetry-demo deployment/ollama -- ollama ps

# Docker Compose
docker-compose exec ollama ollama ps
```

**Solution: Increase resources**
```yaml
# For Kubernetes, edit k8s/02-ollama.yaml
resources:
  limits:
    memory: "4Gi"
    cpu: "2000m"

# For Docker Compose, edit docker-compose.yaml
ollama:
  deploy:
    resources:
      limits:
        memory: 4G
        cpus: '2'
```

---

## Test Checklist

Use this checklist to verify your deployment:

- [ ] All pods/containers are running
- [ ] Health endpoint returns 200 OK
- [ ] Single chat request works
- [ ] Batch requests work
- [ ] Traces appear in Jaeger UI
- [ ] Span attributes are present
- [ ] Application has no tracing code
- [ ] Response times are acceptable (<5s)
- [ ] Sidecar logs show span creation
- [ ] Collector logs show trace reception

---

## Next Steps

After successful testing:

1. **Explore Jaeger UI**: Navigate through different traces and understand the data
2. **Try Different Models**: Change `OLLAMA_MODEL` environment variable
3. **Add Custom Attributes**: Modify [`traceloop-sidecar/proxy.py`](traceloop-sidecar/proxy.py)
4. **Scale Application**: Increase replicas in Kubernetes
5. **Monitor Performance**: Use Jaeger to identify slow operations

## Additional Resources

- [DEPLOYMENT.md](DEPLOYMENT.md) - Deployment guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture details
- [README.md](README.md) - Project overview
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)