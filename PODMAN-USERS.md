# Guide for Podman Users

**⚠️ IMPORTANT: You have `docker compose` installed but you're using Podman as your container engine!**

The `docker compose` command tries to connect to Docker daemon, but you're using Podman. You have two options:

1. **Use Kubernetes (Recommended)** - Follow the instructions below
2. **Use podman-compose** - Install with `brew install podman-compose` (macOS) or `pip install podman-compose`

This guide covers Option 1 (Kubernetes), which is more reliable.

## 🚀 Quick Start (Automated)

**The easiest way to deploy with Podman is to use the automated script:**

```bash
./deploy-podman.sh
```

This script will:
- ✅ Check all prerequisites (Podman, Minikube, kubectl)
- ✅ Start Minikube with proper resources
- ✅ Build both container images with Podman
- ✅ Load images into Minikube
- ✅ Deploy all Kubernetes resources
- ✅ Wait for pods to be ready
- ✅ Display access URLs and useful commands

**Continue reading below for manual step-by-step instructions.**

---

## ✅ Manual Deployment Method for Podman Users

### Step-by-Step Instructions

#### 1. Start Minikube
```bash
minikube start --memory=6144 --cpus=4
```

#### 2. Build Images with Podman
```bash
# Build sidecar
cd traceloop-sidecar
podman build -t traceloop-sidecar:latest .
cd ..

# Build application
cd ollama-simple-app
podman build -t ollama-simple-app:latest .
cd ..
```

#### 3. Load Images into Minikube
```bash
# Load sidecar image
podman save traceloop-sidecar:latest | minikube image load -

# Load app image
podman save ollama-simple-app:latest | minikube image load -
```

#### 4. Deploy to Kubernetes
```bash
kubectl apply -f k8s/
```

#### 5. Check Status
```bash
# Check deployment status
./check-status.sh

# Watch pods (wait for 2/2 Running - takes 5-10 minutes)
kubectl get pods -n openllmetry-demo -w
```

**Wait until you see:**
```
NAME                                 READY   STATUS    RESTARTS   AGE
otel-collector-xxx                   1/1     Running   0          2m
ollama-xxx                           1/1     Running   0          2m
jaeger-xxx                           1/1     Running   0          2m
ollama-simple-app-xxx                2/2     Running   0          1m
```

#### 6. Port-Forward Services

**Terminal 1 - Jaeger UI:**
```bash
kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
```

**Terminal 2 - Application API:**
```bash
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
```

#### 7. Test the Application
```bash
# Health check
curl http://localhost:8080/health

# Chat request
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What is OpenTelemetry?"}'
```

#### 8. View Traces
Open in browser: **http://localhost:16686**

1. Select service: **`ollama-simple-app`**
2. Click **"Find Traces"**
3. Click on any trace to see LLM details

---

## ❌ What NOT to Do

### DO NOT Use start-all.sh Option 1 (Docker Compose)
```bash
./start-all.sh
# Select option 1  ← DON'T DO THIS with Podman!
```

**Why?** Docker Compose requires Docker daemon. You'll get:
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

### DO NOT Use docker-compose Commands
```bash
docker-compose up  ← Won't work with Podman
```

---

## 🔧 Troubleshooting

### Issue: "Cannot connect to Docker daemon"
**Solution**: You're trying to use Docker Compose. Use Kubernetes instead (see instructions above).

### Issue: "Image not known" when loading into Minikube
**Solution**: Build the image first with Podman before trying to load it.

### Issue: Build fails with dependency conflict
**Solution**: Already fixed in latest code. Pull latest changes.

### Issue: Pods stuck in "Pending" or "ContainerCreating"
**Solution**: 
```bash
# Check pod details
kubectl describe pod -n openllmetry-demo <pod-name>

# If "ImagePullBackOff", images weren't loaded
# Rebuild and reload:
cd traceloop-sidecar && podman build -t traceloop-sidecar:latest . && cd ..
podman save traceloop-sidecar:latest | minikube image load -
```

---

## 📋 Quick Command Reference

```bash
# Check status
./check-status.sh

# View logs
./view-logs.sh

# Watch pods
kubectl get pods -n openllmetry-demo -w

# Check specific pod logs
kubectl logs -n openllmetry-demo <pod-name> -c ollama-simple-app -f
kubectl logs -n openllmetry-demo <pod-name> -c traceloop-sidecar -f

# Restart deployment
kubectl rollout restart deployment/ollama-simple-app -n openllmetry-demo

# Delete and redeploy
kubectl delete -f k8s/
kubectl apply -f k8s/

# Complete cleanup
kubectl delete namespace openllmetry-demo
```

---

## 🎯 Summary

**For Podman Users:**
1. ✅ Use Kubernetes (Minikube)
2. ✅ Build with Podman
3. ✅ Load images into Minikube
4. ✅ Deploy with kubectl
5. ❌ DON'T use Docker Compose
6. ❌ DON'T use start-all.sh option 1

**Key Documentation:**
- This file: Quick Podman guide
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md): Detailed troubleshooting
- [QUICK-REFERENCE.md](QUICK-REFERENCE.md): All commands
- [README.md](README.md): Full project documentation