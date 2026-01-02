# 🚀 Quick Start Guide for Podman Users

**Follow this guide step-by-step to deploy and test the OpenLLMetry SideCar project with Podman.**

---

## Prerequisites Check

Before starting, verify you have these installed:

```bash
# Check Podman
podman --version
# Should show: podman version 4.x or higher

# Check Minikube
minikube version
# Should show: minikube version: v1.x

# Check kubectl
kubectl version --client
# Should show: Client Version: v1.x
```

If any are missing, install them:
- **Podman**: https://podman.io/getting-started/installation
- **Minikube**: https://minikube.sigs.k8s.io/docs/start/
- **kubectl**: https://kubernetes.io/docs/tasks/tools/

---

## Step 1: Clean Start (Optional but Recommended)

If you've tried deploying before, clean up first:

```bash
# Stop any standalone Podman containers
podman ps
podman stop $(podman ps -q) 2>/dev/null || true
podman rm $(podman ps -aq) 2>/dev/null || true

# Delete existing Kubernetes deployment
kubectl delete -f k8s/ --ignore-not-found=true

# Restart Minikube (optional, if you had issues)
minikube stop
minikube delete
```

---

## Step 2: Automated Deployment

**Use the automated script (RECOMMENDED):**

```bash
./deploy-podman.sh
```

This script will:
- ✅ Check prerequisites
- ✅ Start Minikube with proper resources (6GB RAM, 4 CPUs)
- ✅ Build your custom images (traceloop-sidecar, ollama-simple-app)
- ✅ Pull public images (ollama, otel-collector, jaeger)
- ✅ Load all images into Minikube
- ✅ Deploy to Kubernetes
- ✅ Show status and next steps

**Expected time:** 10-15 minutes (includes downloading Ollama ~2GB and model ~2GB)

---

## Step 3: Monitor Deployment

Watch the pods start up:

```bash
kubectl get pods -n openllmetry-demo -w
```

**Expected progression:**
1. `ContainerCreating` → Pods are starting
2. `Running` (0/1 or 0/2) → Containers starting
3. `Running` (1/1 or 2/2) → All containers ready

**Press Ctrl+C to stop watching.**

**Note:** The `ollama` pod will take 5-10 minutes to download the Granite3 model (~2GB).

---

## Step 4: Check Status

Once pods show `Running`, verify everything is ready:

```bash
./check-status.sh
```

This will show:
- Pod status
- Service endpoints
- Access URLs
- Next steps

**Wait until all pods show `Running` and `READY` shows `1/1` or `2/2`.**

---

## Step 5: Access the Services

Open **two separate terminal windows** and run these commands:

### Terminal 1: Port-forward Application
```bash
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
```

Keep this running. You should see:
```
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

### Terminal 2: Port-forward Jaeger UI
```bash
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
```

Keep this running. You should see:
```
Forwarding from 127.0.0.1:16686 -> 16686
Forwarding from [::1]:16686 -> 16686
```

---

## Step 6: Test the Application

Open a **third terminal** and test:

### Test 1: Health Check
```bash
curl http://localhost:8080/health
```

**Expected response:**
```json
{
  "status": "healthy",
  "model": "granite3:latest",
  "ollama_host": "http://localhost:11434",
  "log_file": "logs/ollama_app_YYYYMMDD_HHMMSS.log"
}
```

### Test 2: Chat Request
```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry?"}'
```

**Expected response:**
```json
{
  "response": "OpenTelemetry is an observability framework...",
  "request_id": "YYYYMMDD_HHMMSS_XXXXXX"
}
```

**If you get an error**, wait a bit longer - the model might still be downloading. Check with:
```bash
kubectl logs -n openllmetry-demo -l app=ollama -f
```

---

## Step 7: View Traces in Jaeger

1. **Open your browser** to: http://localhost:16686

2. **Select service** from dropdown: `ollama-simple-app`

3. **Click "Find Traces"**

4. **Click on any trace** to see:
   - Request details
   - LLM prompt and response
   - Timing information
   - Sidecar interception

**This proves the sidecar is working - the application has NO tracing code!**

---

## Step 8: View Application Logs

```bash
# Application logs (no tracing code!)
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f

# Sidecar logs (shows tracing magic)
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f
```

Press Ctrl+C to stop viewing logs.

---

## Step 9: Stop Everything

When you're done testing:

```bash
./stop-all.sh
```

This interactive script will:
- Show what's running
- Let you choose what to stop
- Optionally stop Minikube

---

## Troubleshooting

### Issue: Pods stuck in `Pending` or `ImagePullBackOff`

**Solution:**
```bash
./fix-podman-images.sh
```

Then wait and check status again:
```bash
kubectl get pods -n openllmetry-demo -w
```

### Issue: "Name or service not known" error

This means you're running standalone containers instead of the full Kubernetes stack.

**Solution:**
```bash
# Stop standalone containers
podman stop $(podman ps -q)
podman rm $(podman ps -aq)

# Deploy properly
./deploy-podman.sh
```

### Issue: Port-forward fails

**Solution:**
```bash
# Check if pods are running
kubectl get pods -n openllmetry-demo

# If not all Running, wait longer or check logs
kubectl logs -n openllmetry-demo <pod-name>
```

### More Help

See detailed troubleshooting guides:
- **[PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md)** - Podman-specific issues
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - General issues
- **[PODMAN-USERS.md](PODMAN-USERS.md)** - Complete Podman guide

---

## Quick Reference

### Useful Commands

```bash
# Check pod status
kubectl get pods -n openllmetry-demo

# Check detailed pod info
kubectl describe pod <pod-name> -n openllmetry-demo

# View logs
kubectl logs -n openllmetry-demo <pod-name> -c <container-name> -f

# Check images in Minikube
minikube image ls | grep -E "(traceloop|ollama|otel|jaeger)"

# Get Minikube IP (for NodePort access)
minikube ip

# Check deployment status
./check-status.sh
```

### Access URLs (after port-forwarding)

| Service | URL | Purpose |
|---------|-----|---------|
| **Application API** | http://localhost:8080 | Send chat requests |
| **Jaeger UI** | http://localhost:16686 | View traces |
| **Health Check** | http://localhost:8080/health | Verify app is running |

### Test Commands

```bash
# Health check
curl http://localhost:8080/health

# Chat request
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Explain distributed tracing"}'

# Multiple requests to generate traces
for i in {1..5}; do
  curl -X POST http://localhost:8080/chat \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"Request $i: What is AI?\"}"
  echo ""
done
```

---

## What You've Accomplished

✅ Deployed a complete observability stack with Podman and Kubernetes  
✅ Application has **ZERO tracing code** - all handled by sidecar  
✅ Traces automatically captured and sent to Jaeger  
✅ Can view LLM prompts, responses, and timing in Jaeger UI  
✅ Demonstrated the sidecar pattern for adding observability  

---

## Next Steps

- **Explore the code**: See how the sidecar works in [`traceloop-sidecar/proxy.py`](traceloop-sidecar/proxy.py)
- **Read architecture**: Understand the design in [`ARCHITECTURE.md`](ARCHITECTURE.md)
- **View diagrams**: See visual representations in [`DIAGRAMS.md`](DIAGRAMS.md)
- **Customize**: Modify the application in [`ollama-simple-app/app.py`](ollama-simple-app/app.py)

---

**Need help?** Check the documentation:
- [PODMAN-USERS.md](PODMAN-USERS.md) - Complete Podman guide
- [PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md) - Podman-specific issues
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Quick commands
- [DEPLOYMENT.md](DEPLOYMENT.md) - Detailed deployment guide

**Last Updated:** 2026-01-02