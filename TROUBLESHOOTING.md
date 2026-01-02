# Troubleshooting Guide

Common issues and solutions for OpenLLMetry SideCar deployment.

## 🚨 Common Issues

### Issue 0: Docker Build Fails with DNS/Network Timeout

**Symptoms:**
```
ERROR: failed to do request: Head "https://registry-1.docker.io/...":
dial tcp: lookup registry-1.docker.io on 192.168.64.1:53: i/o timeout
```

**Cause:**
- Minikube DNS/networking issue
- Docker daemon in Minikube can't reach Docker Hub

**Solution:**

**Option A: Restart Minikube (Recommended)**
```bash
# Stop Minikube
minikube stop

# Start Minikube with explicit DNS
minikube start --memory=6144 --cpus=4 --dns-domain=cluster.local

# Or just restart
minikube delete
minikube start --memory=6144 --cpus=4

# Then try deployment again
./start-all.sh
```

**Option B: Use Docker Compose Instead**
```bash
# Docker Compose doesn't have this issue
./start-all.sh
# Select option 1 for Docker Compose
```

**Option C: Build Images Outside Minikube**
```bash
# Build with your local Docker (not Minikube's)
# Don't set Minikube Docker env
cd traceloop-sidecar
docker build -t traceloop-sidecar:latest .
cd ..

cd ollama-simple-app
docker build -t ollama-simple-app:latest .
cd ..

# Load images into Minikube
minikube image load traceloop-sidecar:latest
minikube image load ollama-simple-app:latest

# Deploy
kubectl apply -f k8s/
```

**Option D: Check Minikube Network**
```bash
# Check Minikube status
minikube status

# Check if Minikube can reach internet
minikube ssh
# Inside Minikube VM:
ping -c 3 8.8.8.8
ping -c 3 registry-1.docker.io
exit

# If ping fails, restart Minikube
minikube stop
minikube start
```

---

### Issue 0.5: Using Podman with Docker Compose

**Symptoms:**
```
unable to get image 'docker-compose-tr...'
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Cause:**
- You have `docker compose` command installed (Docker Compose V2 plugin)
- BUT you're using Podman as your container engine (not Docker)
- `docker compose` tries to connect to Docker daemon which doesn't exist

**How to Check:**
```bash
# Check what container engine you're using
docker --version  # If this fails, you don't have Docker
podman --version  # If this works, you're using Podman

# Check if docker-compose is trying to use Docker
docker compose version  # This command exists but won't work with Podman
```

**Solution:**

**Option A: Use Podman Compose (For Docker Compose Workflow)**
```bash
# Install podman-compose
# macOS: brew install podman-compose
# Linux: pip install podman-compose

# Use podman-compose instead of docker-compose
cd docker-compose
podman-compose up --build

# Note: podman-compose syntax is identical to docker-compose
```

**Option B: Use Kubernetes (Recommended for Podman users)**
```bash
# Podman works better with Kubernetes
# Use Kind or Minikube with Podman driver

# With Minikube + Podman:
minikube start --driver=podman --memory=6144 --cpus=4

# Then deploy
./start-all.sh
# Select option 2 for Kubernetes
```

**Option C: Switch to Docker**
```bash
# Install Docker Desktop
# https://www.docker.com/products/docker-desktop

# Then use docker-compose normally
./start-all.sh
```

**Option D: Manual Podman Deployment**
```bash
# Build images with Podman
cd traceloop-sidecar
podman build -t traceloop-sidecar:latest .
cd ..

cd ollama-simple-app
podman build -t ollama-simple-app:latest .
cd ..

# Run containers manually with Podman
# (This requires creating a pod and configuring networking)
# See Podman documentation for pod creation
```

---

### Issue 1: start-all.sh Hangs During Build

**Symptoms:**
- Script stops at "Building container images..."
- No progress shown
- Terminal appears frozen

**Cause:**
- Docker build is running but output is hidden
- Build may be downloading base images (slow on first run)

**Solution:**

**Option A: Wait it out (first time only)**
```bash
# First build takes 5-10 minutes to download base images
# Be patient!
```

**Option B: Build manually with visible output**
```bash
# Set Minikube Docker environment
eval $(minikube docker-env)

# Build images one by one (see progress)
cd traceloop-sidecar
docker build -t traceloop-sidecar:latest .
cd ..

cd ollama-simple-app
docker build -t ollama-simple-app:latest .
cd ..

cd ollama-app
docker build -t ollama-app:latest .
cd ..

# Then deploy
kubectl apply -f k8s/
```

**Option C: Use deploy-minikube.sh instead**
```bash
./deploy-minikube.sh
# This script shows build progress
```

---

### Issue 2: "No resources found in openllmetry-demo namespace"

**Symptoms:**
```bash
kubectl get pods -n openllmetry-demo
# No resources found in openllmetry-demo namespace
```

**Cause:**
- Deployment didn't complete
- start-all.sh stopped during build phase

**Solution:**
```bash
# Deploy manually
kubectl apply -f k8s/

# Check status
./check-status.sh

# Watch pods start
kubectl get pods -n openllmetry-demo -w
```

---

### Issue 3: "curl: Failed to connect to localhost port 8080"

**Symptoms:**
```bash
curl http://localhost:8080/health
# curl: (7) Failed to connect to localhost port 8080
```

**Cause:**
- Pods not ready yet
- Port-forward not set up (Kubernetes)
- Services not started (Docker Compose)

**Solution for Kubernetes:**
```bash
# 1. Check if pods are running
kubectl get pods -n openllmetry-demo

# 2. Wait for pods to be Ready (2/2 for ollama-simple-app)
kubectl get pods -n openllmetry-demo -w

# 3. Set up port-forward
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080

# 4. Test (in another terminal)
curl http://localhost:8080/health
```

**Solution for Docker Compose:**
```bash
# 1. Check service status
docker-compose ps

# 2. Wait for services to be "Up"
docker-compose logs -f ollama-simple-app

# 3. Test
curl http://localhost:8080/health
```

---

### Issue 4: Pods Stuck in "Pending" or "ContainerCreating"

**Symptoms:**
```bash
kubectl get pods -n openllmetry-demo
# NAME                                 READY   STATUS              RESTARTS   AGE
# ollama-simple-app-xxx                0/2     ContainerCreating   0          5m
```

**Cause:**
- Images not built
- Insufficient resources
- Init container waiting for dependencies

**Solution:**
```bash
# 1. Check pod details
kubectl describe pod -n openllmetry-demo <pod-name>

# 2. Check events
kubectl get events -n openllmetry-demo --sort-by='.lastTimestamp'

# 3. If "ImagePullBackOff" or "ErrImagePull":
#    Images weren't built in Minikube's Docker
eval $(minikube docker-env)
docker images | grep -E "traceloop-sidecar|ollama-simple-app"

# If images missing, build them:
cd traceloop-sidecar && docker build -t traceloop-sidecar:latest . && cd ..
cd ollama-simple-app && docker build -t ollama-simple-app:latest . && cd ..

# 4. Delete and recreate pod
kubectl delete pod -n openllmetry-demo <pod-name>
```

---

### Issue 5: "Init container waiting for Ollama"

**Symptoms:**
```bash
kubectl logs -n openllmetry-demo <pod-name> -c init-ollama
# Waiting for Ollama to be ready...
# Ollama not ready yet, waiting...
```

**Cause:**
- Ollama pod not running yet
- Ollama service not accessible

**Solution:**
```bash
# 1. Check Ollama pod status
kubectl get pods -n openllmetry-demo -l app=ollama

# 2. Check Ollama logs
kubectl logs -n openllmetry-demo -l app=ollama

# 3. Wait for Ollama to be Running
kubectl get pods -n openllmetry-demo -l app=ollama -w

# 4. Once Ollama is Running, the init container will complete
```

---

### Issue 6: Model Download Taking Forever

**Symptoms:**
- Ollama pod running but app pod not starting
- Init container logs show model pull in progress

**Cause:**
- Granite3 model is ~2GB
- Download speed depends on internet connection

**Solution:**
```bash
# 1. Check Ollama logs for download progress
kubectl logs -n openllmetry-demo -l app=ollama -f

# 2. Check init container logs
kubectl logs -n openllmetry-demo <app-pod-name> -c init-ollama

# 3. Be patient - can take 5-10 minutes

# 4. Alternative: Use smaller model
# Edit k8s/05-ollama-simple-app.yaml:
# Change OLLAMA_MODEL to "tinyllama:latest" (smaller, faster)
```

---

### Issue 7: "No traces in Jaeger"

**Symptoms:**
- Application works
- Jaeger UI accessible
- No traces appear

**Cause:**
- Sidecar not running
- App not pointing to sidecar
- Collector not receiving traces

**Solution:**
```bash
# 1. Check sidecar is running
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar

# 2. Verify app configuration
kubectl exec -n openllmetry-demo <pod-name> -c ollama-simple-app -- env | grep OLLAMA_HOST
# Should show: http://localhost:11434

# 3. Check collector logs
kubectl logs -n openllmetry-demo -l app=otel-collector | grep -i trace

# 4. Make a test request
curl -X POST http://localhost:8080/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test"}'

# 5. Check Jaeger UI again (may take a few seconds)
```

---

### Issue 8: Docker Compose Services Not Starting

**Symptoms:**
```bash
docker-compose ps
# Services show "Exit 1" or "Restarting"
```

**Cause:**
- Port conflicts
- Resource constraints
- Configuration errors

**Solution:**
```bash
# 1. Check logs for errors
docker-compose logs

# 2. Check specific service
docker-compose logs ollama-simple-app

# 3. Check for port conflicts
lsof -i :8080  # Application port
lsof -i :16686 # Jaeger port
lsof -i :11434 # Ollama port

# 4. Restart services
docker-compose restart

# 5. If still failing, rebuild
docker-compose down
docker-compose up --build
```

---

## 🔧 Diagnostic Commands

### Check Everything
```bash
# Quick status check
./check-status.sh

# Detailed Kubernetes status
kubectl get all -n openllmetry-demo
kubectl get events -n openllmetry-demo --sort-by='.lastTimestamp'

# Detailed Docker Compose status
docker-compose ps
docker-compose logs --tail=50
```

### Check Specific Components

**Ollama:**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=ollama
kubectl exec -n openllmetry-demo deployment/ollama -- ollama list

# Docker Compose
docker-compose logs ollama
docker-compose exec ollama ollama list
```

**Application:**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app
kubectl exec -n openllmetry-demo <pod-name> -c ollama-simple-app -- env

# Docker Compose
docker-compose logs ollama-simple-app
docker-compose exec ollama-simple-app env
```

**Sidecar:**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar

# Docker Compose
docker-compose logs traceloop-sidecar
```

**Collector:**
```bash
# Kubernetes
kubectl logs -n openllmetry-demo -l app=otel-collector

# Docker Compose
docker-compose logs otel-collector
```

---

## 🆘 Nuclear Options

### Complete Reset (Kubernetes)
```bash
# Delete everything
kubectl delete namespace openllmetry-demo

# Stop Minikube
minikube stop

# Delete Minikube cluster
minikube delete

# Start fresh
minikube start --memory=6144 --cpus=4
./start-all.sh
```

### Complete Reset (Docker Compose)
```bash
# Stop and remove everything
cd docker-compose
docker-compose down -v

# Remove images
docker-compose down --rmi all -v

# Start fresh
docker-compose up --build
```

---

## 📊 Resource Requirements

### Minimum Requirements
- **RAM**: 6GB available
- **CPU**: 2 cores
- **Disk**: 10GB free space

### Check Resources

**Kubernetes:**
```bash
# Minikube resources
minikube status

# Pod resources
kubectl top pods -n openllmetry-demo

# Node resources
kubectl top nodes
```

**Docker:**
```bash
# Container resources
docker stats

# System resources
docker system df
```

---

## 💡 Tips

1. **First deployment is slow** - Base images and models need to download
2. **Use check-status.sh** - Always check status before testing
3. **Port-forward is required** - Kubernetes needs port-forward for local access
4. **Watch logs** - Use `./view-logs.sh` to monitor progress
5. **Be patient** - Model download takes 5-10 minutes
6. **Check documentation** - See [QUICK-REFERENCE.md](QUICK-REFERENCE.md) for commands

---

## 📞 Still Having Issues?

1. Run diagnostics:
   ```bash
   ./check-status.sh
   ./view-logs.sh
   ```

2. Check documentation:
   - [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Commands and URLs
   - [DEPLOYMENT.md](DEPLOYMENT.md) - Detailed deployment guide
   - [TESTING.md](TESTING.md) - Testing procedures

3. Collect information:
   ```bash
   # Kubernetes
   kubectl get all -n openllmetry-demo > debug-k8s.txt
   kubectl get events -n openllmetry-demo >> debug-k8s.txt
   kubectl logs -n openllmetry-demo -l app=ollama-simple-app --all-containers >> debug-k8s.txt
   
   # Docker Compose
   docker-compose ps > debug-docker.txt
   docker-compose logs >> debug-docker.txt
   ```

4. Review logs in `./logs` directory for application-specific issues