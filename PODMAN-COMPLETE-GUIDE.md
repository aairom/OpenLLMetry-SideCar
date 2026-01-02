# Complete Guide for Podman Users

**Everything you need to deploy and troubleshoot OpenLLMetry SideCar with Podman + Minikube.**

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Prerequisites](#prerequisites)
3. [Complete Setup Process](#complete-setup-process)
4. [Testing the Application](#testing-the-application)
5. [Troubleshooting](#troubleshooting)
6. [Cleanup](#cleanup)
7. [Architecture Overview](#architecture-overview)
8. [Scripts Reference](#scripts-reference)
9. [Advanced Topics](#advanced-topics)

---

## Quick Start

**TL;DR - Get running in 3 commands:**

```bash
# 1. Start Minikube with adequate disk space (CRITICAL!)
minikube start --memory=6144 --cpus=4 --disk-size=40g

# 2. Deploy everything
./deploy-podman.sh

# 3. Monitor deployment (wait 15-20 minutes)
kubectl get pods -n openllmetry-demo -w
```

Then follow [Testing the Application](#testing-the-application) section.

---

## Prerequisites

### Required Software

Verify you have these installed:

```bash
# Check Podman (4.x or higher)
podman --version

# Check Minikube (v1.x or higher)
minikube version

# Check kubectl (v1.x or higher)
kubectl version --client
```

### Installation Links

If any are missing:
- **Podman**: https://podman.io/getting-started/installation
- **Minikube**: https://minikube.sigs.k8s.io/docs/start/
- **kubectl**: https://kubernetes.io/docs/tasks/tools/

### System Requirements

- **RAM**: 6GB available for Minikube
- **CPU**: 4 cores recommended
- **Disk**: 40GB for Minikube (critical for ollama image)
- **OS**: macOS, Linux, or Windows with WSL2

---

## Complete Setup Process

### Step 1: Clean Start (If Needed)

If you've tried deploying before, clean up first:

```bash
# Stop any standalone Podman containers
podman ps
podman stop $(podman ps -q) 2>/dev/null || true
podman rm $(podman ps -aq) 2>/dev/null || true

# Delete existing Minikube cluster
minikube delete
```

### Step 2: Start Minikube with Adequate Resources

**⚠️ CRITICAL:** Use 40GB disk space (not the default 20GB):

```bash
minikube start --memory=6144 --cpus=4 --disk-size=40g
```

**Why 40GB?**
- ollama/ollama image: ~5.4GB
- Other images: ~2GB
- Kubernetes overhead: ~2GB
- Working space: ~30GB

Wait 2-3 minutes for Minikube to fully start.

**Verify Minikube is running:**
```bash
minikube status
# Should show: host, kubelet, apiserver all "Running"
```

### Step 3: Automated Deployment

Run the deployment script:

```bash
./deploy-podman.sh
```

**What this script does:**

1. ✅ Checks prerequisites (Podman, Minikube, kubectl)
2. ✅ Builds custom images with Podman:
   - `localhost/traceloop-sidecar:latest`
   - `localhost/ollama-simple-app:latest`
3. ✅ Loads custom images into Minikube
4. ✅ Pulls public images with Podman:
   - `docker.io/ollama/ollama:latest` (~5.4GB)
   - `docker.io/otel/opentelemetry-collector-contrib:0.93.0`
   - `docker.io/jaegertracing/all-in-one:latest`
5. ✅ Loads public images into Minikube
6. ✅ Deploys all Kubernetes resources
7. ✅ Shows deployment status

**Expected time:** 15-20 minutes (includes downloading ~7GB of images)

**Expected output:**
```
================================================
OpenLLMetry SideCar - Podman Deployment
================================================

✅ All required tools are installed
✅ Minikube is already running
✅ traceloop-sidecar built successfully
✅ ollama-simple-app built successfully
✅ Images loaded into Minikube
✅ Public images pulled and loaded
✅ Deployment Complete!
```

### Step 4: Monitor Deployment

Watch pods start up:

```bash
kubectl get pods -n openllmetry-demo -w
```

**Expected progression:**

| Pod | Initial Status | Final Status | Time |
|-----|---------------|--------------|------|
| otel-collector | ContainerCreating | Running (1/1) | 1-2 min |
| jaeger | ContainerCreating | Running (1/1) | 1-2 min |
| ollama | Init:0/1 | Running (1/1) | 5-10 min |
| ollama-simple-app | Init:0/1 | Running (2/2) | After ollama |

**Note:** The ollama pod takes 5-10 minutes because it downloads the Granite3 model (~2GB).

Press `Ctrl+C` to stop watching.

### Step 5: Verify Deployment

Check status with the helper script:

```bash
./check-status.sh
```

**Expected output:**
```
All pods should show:
- STATUS: Running
- READY: 1/1 or 2/2
```

**If pods are not ready:**
- Wait longer (ollama model download takes time)
- Check logs: `kubectl logs -n openllmetry-demo <pod-name>`
- See [Troubleshooting](#troubleshooting) section

---

## Testing the Application

### Step 1: Port-Forward Services

Open **two separate terminal windows**:

**Terminal 1 - Application API:**
```bash
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
```

Keep this running. You should see:
```
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

**Terminal 2 - Jaeger UI:**
```bash
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
```

Keep this running. You should see:
```
Forwarding from 127.0.0.1:16686 -> 16686
Forwarding from [::1]:16686 -> 16686
```

### Step 2: Test Health Check

In a **third terminal**:

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

### Step 3: Test Chat Request

```bash
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry?"}'
```

**Expected response:**
```json
{
  "response": "OpenTelemetry is an observability framework for cloud-native software...",
  "request_id": "YYYYMMDD_HHMMSS_XXXXXX"
}
```

**If you get an error:**
- Check if ollama pod is running: `kubectl get pods -n openllmetry-demo`
- Check ollama logs: `kubectl logs -n openllmetry-demo -l app=ollama -f`
- Wait longer - model might still be downloading

### Step 4: Generate Multiple Requests

Create several traces for better visualization:

```bash
for i in {1..5}; do
  curl -X POST http://localhost:8080/chat \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"Request $i: Explain distributed tracing\"}"
  echo ""
  sleep 2
done
```

### Step 5: View Traces in Jaeger

1. **Open browser:** http://localhost:16686

2. **Select service:** From the dropdown, choose `ollama-simple-app`

3. **Click "Find Traces"**

4. **Explore a trace:** Click on any trace to see:
   - **Span details**: Request timing, duration
   - **Tags**: LLM model, prompt, response
   - **Logs**: Application events
   - **Process**: Service information

**What you're seeing:**
- The application has **ZERO tracing code**
- The sidecar intercepts all Ollama API calls
- Traces are automatically created and sent to Jaeger
- Complete visibility into LLM interactions

### Step 6: View Application Logs

```bash
# Application logs (no tracing code!)
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f

# Sidecar logs (shows tracing magic)
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f
```

Press `Ctrl+C` to stop viewing logs.

---

## Troubleshooting

### Issue 1: API Server Stopped / Connection Refused

**Symptoms:**
```
The connection to the server 192.168.64.3:8443 was refused
```

**Cause:** Minikube API server stopped, usually due to insufficient disk space.

**Solution:**
```bash
# Check Minikube status
minikube status
# If apiserver shows "Stopped"

# Delete and recreate with more disk space
minikube delete
minikube start --memory=6144 --cpus=4 --disk-size=40g
./deploy-podman.sh
```

### Issue 2: DNS Error - "Name or service not known"

**Symptoms:**
```bash
curl http://localhost:8080/chat
# Returns: {"error":"[Errno -2] Name or service not known",...}
```

**Cause:** Application container running standalone (not in Kubernetes) trying to connect to `http://ollama:11434` which doesn't exist in Podman network.

**Solution:**
```bash
# Stop any standalone containers
podman ps
podman stop <container-name>
podman rm <container-name>

# Deploy properly to Kubernetes
./deploy-podman.sh
```

### Issue 3: ImagePullBackOff in Kubernetes

**Symptoms:**
```bash
kubectl get pods -n openllmetry-demo
# Shows: ImagePullBackOff or ErrImagePull
```

**Cause:** Kubernetes can't find images because:
- Images built with Podman have `localhost/` prefix
- Public images aren't loaded into Minikube
- Minikube can't pull from Docker Hub (DNS issues)

**Solution A: Use fix script (Quick)**
```bash
./fix-podman-images.sh
```

**Solution B: Manual fix**
```bash
# 1. Pull public images with Podman
podman pull ollama/ollama:latest
podman pull otel/opentelemetry-collector-contrib:0.93.0
podman pull jaegertracing/all-in-one:latest

# 2. Load into Minikube
podman save ollama/ollama:latest -o /tmp/ollama.tar
minikube image load /tmp/ollama.tar
rm /tmp/ollama.tar

podman save otel/opentelemetry-collector-contrib:0.93.0 | minikube image load -
podman save jaegertracing/all-in-one:latest | minikube image load -

# 3. Verify images
minikube image ls | grep -E "(ollama|otel|jaeger)"

# 4. Restart deployments
kubectl rollout restart deployment -n openllmetry-demo --all
```

### Issue 4: Pods Stuck in Pending

**Symptoms:**
```bash
kubectl get pods -n openllmetry-demo
# Shows: Pending status for extended time
```

**Cause:** Minikube doesn't have enough resources or images aren't available.

**Solution:**
```bash
# 1. Check Minikube resources
minikube status

# 2. Check if images are loaded
minikube image ls | grep -E "(traceloop|ollama|otel|jaeger)"

# 3. If images missing, reload them
./fix-podman-images.sh

# 4. If still pending, restart Minikube with more resources
minikube stop
minikube start --memory=6144 --cpus=4 --disk-size=40g
./deploy-podman.sh
```

### Issue 5: "Cannot connect to Docker daemon"

**Symptoms:**
```bash
docker compose up
# Error: Cannot connect to the Docker daemon
```

**Cause:** You have `docker compose` command but Podman as container engine. The command tries to connect to Docker daemon which doesn't exist.

**Solution:** Use Kubernetes instead of Docker Compose:
```bash
./deploy-podman.sh
```

**Alternative:** Install podman-compose:
```bash
# macOS
brew install podman-compose

# Then use podman-compose
cd docker-compose
podman-compose up --build
```

### Issue 6: Minikube DNS Timeout During Build

**Symptoms:**
```bash
minikube ssh -- docker build ...
# Error: dial tcp: lookup registry-1.docker.io... i/o timeout
```

**Cause:** Minikube's internal Docker daemon can't reach Docker Hub.

**Solution:** Build with Podman locally and load into Minikube (this is what deploy-podman.sh does):
```bash
cd traceloop-sidecar
podman build -t traceloop-sidecar:latest .
podman save traceloop-sidecar:latest | minikube image load -
cd ..

cd ollama-simple-app
podman build -t ollama-simple-app:latest .
podman save ollama-simple-app:latest | minikube image load -
cd ..
```

### Issue 7: Ollama Pod Not Starting

**Symptoms:** Ollama pod shows `ImagePullBackOff` or `Pending`

**Solution:**
```bash
# Check if ollama image is in Minikube
minikube image ls | grep ollama

# If missing, load it
podman pull ollama/ollama:latest
podman save ollama/ollama:latest -o /tmp/ollama.tar
minikube image load /tmp/ollama.tar
rm /tmp/ollama.tar

# Restart deployment
kubectl rollout restart deployment/ollama -n openllmetry-demo

# Monitor
kubectl get pods -n openllmetry-demo -w
```

### Issue 8: Port-Forward Fails

**Symptoms:** `error forwarding port` or connection refused

**Solution:**
```bash
# 1. Check if pods are running
kubectl get pods -n openllmetry-demo

# 2. If not all Running, check logs
kubectl logs -n openllmetry-demo <pod-name>

# 3. Verify service exists
kubectl get svc -n openllmetry-demo

# 4. Try port-forward again
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
```

### Issue 9: No Space Left on Device

**Symptoms:**
```
mkdir /var/lib/docker/tmp/docker-import-xxx: no space left on device
```

**Cause:** Minikube ran out of disk space (default 20GB is insufficient for ollama image).

**Solution:**
```bash
# Delete and recreate with more disk space
minikube delete
minikube start --memory=6144 --cpus=4 --disk-size=40g
./deploy-podman.sh
```

### Debugging Checklist

Use this checklist when troubleshooting:

- [ ] **Minikube running?**
  ```bash
  minikube status
  # All should show "Running"
  ```

- [ ] **Images in Minikube?**
  ```bash
  minikube image ls | grep -E "(traceloop|ollama|otel|jaeger)"
  # Should show all 5 images
  ```

- [ ] **Pods running?**
  ```bash
  kubectl get pods -n openllmetry-demo
  # All should show "Running" with READY 1/1 or 2/2
  ```

- [ ] **Services exist?**
  ```bash
  kubectl get svc -n openllmetry-demo
  # Should show ollama-simple-app, jaeger, ollama, otel-collector
  ```

- [ ] **Port-forwards active?**
  ```bash
  # Check if terminals are still running port-forward commands
  ```

- [ ] **Application responding?**
  ```bash
  curl http://localhost:8080/health
  # Should return JSON with "status":"healthy"
  ```

---

## Cleanup

### Quick Cleanup

Stop services but keep images:

```bash
./stop-all.sh
```

### Complete Cleanup

Remove everything (images, deployments, Minikube):

```bash
./cleanup-all-images.sh
```

This script will:
1. Delete Kubernetes deployments and services
2. Remove images from Minikube
3. Remove images from Podman (custom + public)
4. Clean temporary files
5. Optionally delete Minikube cluster

### Manual Cleanup

If you prefer manual cleanup:

```bash
# 1. Delete Kubernetes resources
kubectl delete -f k8s/

# 2. Stop Minikube
minikube stop

# 3. Delete Minikube cluster
minikube delete

# 4. Remove Podman images
podman rmi localhost/traceloop-sidecar:latest
podman rmi localhost/ollama-simple-app:latest
podman rmi docker.io/ollama/ollama:latest
podman rmi docker.io/otel/opentelemetry-collector-contrib:0.93.0
podman rmi docker.io/jaegertracing/all-in-one:latest

# 5. Clean temporary files
rm -rf ./logs
rm -f /tmp/ollama.tar
```

### Start Fresh

After cleanup, start fresh:

```bash
minikube start --memory=6144 --cpus=4 --disk-size=40g
./deploy-podman.sh
```

---

## Architecture Overview

### System Architecture

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

### Key Components

1. **Ollama Simple App**
   - Pure Flask application
   - **NO tracing code** - completely clean
   - Connects to `localhost:11434` (thinks it's Ollama)
   - Actually connects to sidecar

2. **TraceLoop Sidecar**
   - Transparent proxy
   - Intercepts all Ollama API calls
   - Adds OpenTelemetry tracing automatically
   - Forwards requests to real Ollama

3. **Ollama**
   - LLM engine (Granite3 model)
   - Receives proxied requests from sidecar
   - Returns LLM responses

4. **OpenTelemetry Collector**
   - Receives traces from sidecar (OTLP/gRPC)
   - Processes and batches traces
   - Forwards to Jaeger

5. **Jaeger**
   - Trace storage and visualization
   - Web UI for viewing traces
   - Shows complete LLM interaction details

### Request Flow

```
User Request
    │
    ▼
Application (localhost:8080)
    │
    │ Makes Ollama API call to localhost:11434
    ▼
Sidecar (localhost:11434)
    │
    │ 1. Creates trace span
    │ 2. Adds OpenTelemetry context
    │ 3. Proxies to real Ollama
    ▼
Ollama (ollama:11434)
    │
    │ Generates LLM response
    ▼
Sidecar
    │
    │ 1. Captures response
    │ 2. Completes span
    │ 3. Sends trace to collector
    ▼
Application
    │
    │ Returns response to user
    ▼
User

    (Parallel)
    Sidecar ──OTLP──▶ Collector ──▶ Jaeger
```

### Deployment Architecture

**Kubernetes (Recommended for Podman):**
- Application and sidecar in same pod (share localhost)
- Separate pods for ollama, collector, jaeger
- Service DNS for inter-pod communication
- NodePort or port-forward for external access

**Docker Compose (Not recommended for Podman):**
- Separate containers on shared network
- DNS resolution via container names
- Direct port mapping to host

### Why Sidecar Pattern?

**Benefits:**
- ✅ **Zero code changes** - Application stays clean
- ✅ **Separation of concerns** - Tracing is infrastructure
- ✅ **Easy updates** - Update sidecar without touching app
- ✅ **Reusable** - Same sidecar for multiple apps
- ✅ **Transparent** - App doesn't know it's being traced

**Trade-offs:**
- Additional container in pod
- Slight latency overhead (minimal)
- More complex deployment (handled by scripts)

---

## Scripts Reference

### Deployment Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `./deploy-podman.sh` | Complete automated deployment | First time setup or clean deployment |
| `./fix-podman-images.sh` | Fix image issues in existing deployment | When pods show ImagePullBackOff |

### Management Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `./check-status.sh` | Check deployment status | Monitor deployment progress |
| `./view-logs.sh` | View and manage logs | Debugging or monitoring |
| `./stop-all.sh` | Stop services | When done testing |
| `./cleanup-all-images.sh` | Purge all images and resources | Complete cleanup |

### Script Details

#### deploy-podman.sh

**What it does:**
1. Checks prerequisites
2. Starts Minikube (if not running)
3. Builds custom images with Podman
4. Loads custom images into Minikube
5. Pulls public images with Podman
6. Loads public images into Minikube
7. Deploys to Kubernetes
8. Shows status

**Usage:**
```bash
./deploy-podman.sh
```

**Time:** 15-20 minutes (first run with downloads)

#### fix-podman-images.sh

**What it does:**
1. Checks if images exist in Podman
2. Pulls missing images
3. Loads images into Minikube
4. Restarts deployments

**Usage:**
```bash
./fix-podman-images.sh
```

**Time:** 5-10 minutes (depending on what's missing)

#### check-status.sh

**What it does:**
1. Shows pod status
2. Shows service endpoints
3. Provides access URLs
4. Suggests next steps

**Usage:**
```bash
./check-status.sh
```

#### cleanup-all-images.sh

**What it does:**
1. Deletes Kubernetes resources
2. Removes images from Minikube
3. Removes images from Podman
4. Cleans temporary files
5. Optionally deletes Minikube cluster

**Usage:**
```bash
./cleanup-all-images.sh
```

**Interactive:** Asks for confirmation before each major step

---

## Advanced Topics

### Using External Ollama

If you want to run Ollama outside Kubernetes:

```bash
# 1. Run Ollama with Podman
podman run -d -p 11434:11434 --name ollama ollama/ollama:latest

# 2. Delete ollama deployment from Kubernetes
kubectl delete deployment ollama -n openllmetry-demo

# 3. Update ollama-simple-app to use host.minikube.internal
kubectl set env deployment/ollama-simple-app \
  -n openllmetry-demo \
  OLLAMA_HOST=http://host.minikube.internal:11434

# 4. Restart app
kubectl rollout restart deployment/ollama-simple-app -n openllmetry-demo
```

### Custom Model

To use a different Ollama model:

```bash
# 1. Update environment variable
kubectl set env deployment/ollama-simple-app \
  -n openllmetry-demo \
  OLLAMA_MODEL=llama2:latest

# 2. Restart app
kubectl rollout restart deployment/ollama-simple-app -n openllmetry-demo

# 3. Pull model in ollama pod
kubectl exec -n openllmetry-demo deployment/ollama -- \
  ollama pull llama2:latest
```

### Persistent Storage

To persist Ollama models across restarts:

```bash
# 1. Create PersistentVolumeClaim
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-data
  namespace: openllmetry-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# 2. Update ollama deployment to use PVC
# Edit k8s/02-ollama.yaml and change emptyDir to persistentVolumeClaim

# 3. Redeploy
kubectl apply -f k8s/02-ollama.yaml
```

### Scaling

To run multiple application instances:

```bash
# Scale up
kubectl scale deployment/ollama-simple-app -n openllmetry-demo --replicas=3

# Scale down
kubectl scale deployment/ollama-simple-app -n openllmetry-demo --replicas=1
```

### Monitoring Resources

```bash
# Pod resource usage
kubectl top pods -n openllmetry-demo

# Node resource usage
kubectl top nodes

# Minikube dashboard
minikube dashboard
```

---

## Quick Reference

### Essential Commands

```bash
# Start Minikube
minikube start --memory=6144 --cpus=4 --disk-size=40g

# Deploy
./deploy-podman.sh

# Check status
kubectl get pods -n openllmetry-demo
./check-status.sh

# Port-forward
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686

# Test
curl http://localhost:8080/health
curl -X POST http://localhost:8080/chat -H "Content-Type: application/json" -d '{"prompt": "test"}'

# View logs
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f

# Cleanup
./cleanup-all-images.sh
```

### Access URLs

| Service | URL | Purpose |
|---------|-----|---------|
| Application API | http://localhost:8080 | Send chat requests |
| Jaeger UI | http://localhost:16686 | View traces |
| Health Check | http://localhost:8080/health | Verify app status |

### Image Names

| Image | Location | Size |
|-------|----------|------|
| localhost/traceloop-sidecar:latest | Custom built | ~200MB |
| localhost/ollama-simple-app:latest | Custom built | ~180MB |
| docker.io/ollama/ollama:latest | Public | ~5.4GB |
| docker.io/otel/opentelemetry-collector-contrib:0.93.0 | Public | ~200MB |
| docker.io/jaegertracing/all-in-one:latest | Public | ~100MB |

---

## Success Criteria

You know everything is working when:

1. ✅ All pods show `Running` status
2. ✅ Health check returns `{"status":"healthy",...}`
3. ✅ Chat requests return LLM responses
4. ✅ Traces appear in Jaeger UI with:
   - Service name: `ollama-simple-app`
   - Span details showing LLM interactions
   - Timing information
5. ✅ Application logs show NO tracing code
6. ✅ Sidecar logs show trace creation and forwarding

---

## Related Documentation

- **[DIAGRAMS.md](DIAGRAMS.md)** - Visual architecture and flow diagrams
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture documentation
- **[QUICK-REFERENCE.md](QUICK-REFERENCE.md)** - Quick command reference
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - General deployment guide
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - General troubleshooting

---

## Getting Help

If you encounter issues not covered here:

1. **Check pod status:**
   ```bash
   kubectl get pods -n openllmetry-demo
   kubectl describe pod <pod-name> -n openllmetry-demo
   ```

2. **Check logs:**
   ```bash
   kubectl logs <pod-name> -n openllmetry-demo -c <container-name>
   ```

3. **Verify images:**
   ```bash
   minikube image ls | grep -E "(traceloop|ollama|otel|jaeger)"
   ```

4. **Check services:**
   ```bash
   kubectl get svc -n openllmetry-demo
   ```

5. **Review this guide's [Troubleshooting](#troubleshooting) section**

---

**Last Updated:** 2026-01-02

**Status:** Complete and tested with Podman + Minikube

**Maintainer:** OpenLLMetry SideCar Project