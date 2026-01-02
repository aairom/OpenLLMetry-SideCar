# Final Setup Guide - Podman + Minikube

This is the definitive guide to get OpenLLMetry SideCar working with Podman and Minikube.

## Prerequisites

Ensure you have these installed:
```bash
podman --version    # Should show 4.x or higher
minikube version    # Should show v1.x
kubectl version     # Should show v1.x
```

## Complete Setup Process

### Step 1: Start Minikube with Adequate Resources

**CRITICAL:** Use 40GB disk space (not the default 20GB) to accommodate the ollama image (5.4GB):

```bash
minikube start --memory=6144 --cpus=4 --disk-size=40g
```

Wait for Minikube to fully start (2-3 minutes).

### Step 2: Deploy Everything

Run the automated deployment script:

```bash
./deploy-podman.sh
```

This script will:
1. ✅ Check prerequisites
2. ✅ Build custom images with Podman
3. ✅ Load images into Minikube
4. ✅ Pull and load public images (ollama, otel-collector, jaeger)
5. ✅ Deploy to Kubernetes
6. ✅ Show deployment status

**Expected time:** 15-20 minutes (includes downloading ~7GB of images)

### Step 3: Monitor Deployment

Watch pods start up:

```bash
kubectl get pods -n openllmetry-demo -w
```

**Wait for all pods to show `Running` status:**
- `otel-collector` - Should be ready in 1-2 minutes
- `jaeger` - Should be ready in 1-2 minutes  
- `ollama` - Takes 5-10 minutes (downloads model ~2GB)
- `ollama-simple-app` - Starts after ollama is ready

Press `Ctrl+C` to stop watching.

### Step 4: Verify Deployment

Check status:

```bash
./check-status.sh
```

All pods should show `Running` with `READY` showing `1/1` or `2/2`.

### Step 5: Access Services

Open **two separate terminals** for port-forwarding:

**Terminal 1 - Application:**
```bash
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
```

**Terminal 2 - Jaeger UI:**
```bash
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
```

Keep both terminals running.

### Step 6: Test the Application

In a **third terminal**, test the application:

```bash
# Health check
curl http://localhost:8080/health

# Expected response:
# {"status":"healthy","model":"granite3:latest",...}

# Chat request
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry?"}'

# Expected response:
# {"response":"OpenTelemetry is...","request_id":"..."}
```

### Step 7: View Traces

1. Open browser: http://localhost:16686
2. Select service: `ollama-simple-app`
3. Click "Find Traces"
4. Click any trace to see:
   - LLM prompt and response
   - Timing information
   - Sidecar interception details

**This proves the sidecar pattern works - the app has NO tracing code!**

## Common Issues & Solutions

### Issue 1: API Server Stopped

**Symptom:**
```
The connection to the server was refused
```

**Cause:** Insufficient disk space in Minikube

**Solution:**
```bash
minikube delete
minikube start --memory=6144 --cpus=4 --disk-size=40g
./deploy-podman.sh
```

### Issue 2: Pods Stuck in Pending

**Symptom:**
```bash
kubectl get pods -n openllmetry-demo
# Shows: Pending or ImagePullBackOff
```

**Solution:**
```bash
./fix-podman-images.sh
```

### Issue 3: Ollama Pod Not Starting

**Symptom:** Ollama pod shows `ImagePullBackOff`

**Solution:**
```bash
# Verify image is in Minikube
minikube image ls | grep ollama

# If missing, reload it
podman save docker.io/ollama/ollama:latest -o /tmp/ollama.tar
minikube image load /tmp/ollama.tar
rm /tmp/ollama.tar

# Restart deployment
kubectl rollout restart deployment/ollama -n openllmetry-demo
```

### Issue 4: Port-Forward Fails

**Symptom:** `error forwarding port`

**Solution:**
```bash
# Check if pods are running
kubectl get pods -n openllmetry-demo

# If not all Running, wait longer or check logs
kubectl logs -n openllmetry-demo <pod-name>
```

## Cleanup

### Clean Up Everything

To remove all images and resources:

```bash
./cleanup-all-images.sh
```

This will:
- Delete Kubernetes deployments
- Remove images from Minikube
- Remove images from Podman
- Clean temporary files
- Optionally delete Minikube cluster

### Restart Fresh

```bash
./cleanup-all-images.sh
minikube start --memory=6144 --cpus=4 --disk-size=40g
./deploy-podman.sh
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application Pod                               │
│                                                                  │
│  ┌──────────────────┐         ┌─────────────────────┐          │
│  │  Ollama Simple   │────────▶│  TraceLoop Sidecar  │          │
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
                                            │
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

## Key Points

✅ **Application has ZERO tracing code** - All tracing handled by sidecar  
✅ **Sidecar intercepts all Ollama API calls** - Transparent to application  
✅ **Traces flow through OpenTelemetry Collector** - Standard observability pipeline  
✅ **View everything in Jaeger** - Complete visibility into LLM interactions  

## Documentation Reference

- **[START-HERE-PODMAN.md](START-HERE-PODMAN.md)** - Detailed step-by-step guide
- **[PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md)** - Comprehensive troubleshooting
- **[DIAGRAMS.md](DIAGRAMS.md)** - All mermaid diagrams
- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Quick commands
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture details

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `./deploy-podman.sh` | Automated deployment |
| `./check-status.sh` | Check deployment status |
| `./fix-podman-images.sh` | Fix image issues |
| `./cleanup-all-images.sh` | Purge all images |
| `./stop-all.sh` | Stop services |
| `./view-logs.sh` | View logs |

## Success Criteria

You know it's working when:

1. ✅ All pods show `Running` status
2. ✅ Health check returns `{"status":"healthy",...}`
3. ✅ Chat requests return LLM responses
4. ✅ Traces appear in Jaeger UI
5. ✅ Application logs show NO tracing code
6. ✅ Sidecar logs show trace creation

## Next Steps

After successful deployment:

1. **Explore the code** - See how the sidecar works in `traceloop-sidecar/proxy.py`
2. **Modify the app** - Change `ollama-simple-app/app.py` (no tracing code needed!)
3. **View traces** - Analyze LLM interactions in Jaeger
4. **Read architecture** - Understand the design in `ARCHITECTURE.md`

---

**Last Updated:** 2026-01-02

**Status:** Complete and tested with Podman + Minikube