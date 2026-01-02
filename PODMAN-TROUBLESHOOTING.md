# Podman-Specific Troubleshooting Guide

This guide addresses common issues when using Podman with this project.

## Issue 1: DNS Error - "Name or service not known"

### Symptoms
```bash
curl http://localhost:8080/health
# Works: {"status":"healthy",...}

curl -X POST http://localhost:8080/chat -H "Content-Type: application/json" -d '{"prompt": "test"}'
# Fails: {"error":"[Errno -2] Name or service not known",...}
```

### Root Cause
The application container is running standalone (not in Kubernetes) and trying to connect to `http://ollama:11434`, but there's no ollama service available in the Podman network.

### Solution
You must run the **complete stack**, not individual containers. Use Kubernetes deployment:

```bash
# 1. Stop any standalone containers
podman ps
podman stop <container-name>
podman rm <container-name>

# 2. Deploy to Kubernetes
./fix-podman-images.sh

# 3. Wait for pods to be ready
kubectl get pods -n openllmetry-demo -w

# 4. Port-forward when ready
kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
```

---

## Issue 2: ImagePullBackOff in Kubernetes

### Symptoms
```bash
kubectl get pods -n openllmetry-demo
# Shows: ImagePullBackOff or ErrImagePull
```

### Root Cause
Kubernetes can't find the images because:
1. Images built with Podman have `localhost/` prefix
2. Public images (ollama, otel-collector, jaeger) aren't loaded into Minikube
3. Minikube can't pull from Docker Hub due to DNS issues

### Solution A: Use fix-podman-images.sh (Quick Fix)
```bash
./fix-podman-images.sh
```

### Solution B: Manual Fix
```bash
# 1. Pull public images
podman pull ollama/ollama:latest
podman pull otel/opentelemetry-collector-contrib:0.93.0
podman pull jaegertracing/all-in-one:latest

# 2. Load into Minikube
podman save ollama/ollama:latest | minikube image load -
podman save otel/opentelemetry-collector-contrib:0.93.0 | minikube image load -
podman save jaegertracing/all-in-one:latest | minikube image load -

# 3. Verify images in Minikube
minikube image ls | grep -E "(ollama|otel|jaeger)"

# 4. Restart deployments
kubectl rollout restart deployment -n openllmetry-demo --all
```

---

## Issue 3: Pods Stuck in Pending

### Symptoms
```bash
kubectl get pods -n openllmetry-demo
# Shows: Pending status for extended time
```

### Root Cause
Minikube doesn't have enough resources or images aren't available.

### Solution
```bash
# 1. Check Minikube resources
minikube status

# 2. Restart with more resources if needed
minikube stop
minikube start --memory=6144 --cpus=4

# 3. Reload images
./deploy-podman.sh
```

---

## Issue 4: "Cannot connect to Docker daemon"

### Symptoms
```bash
docker compose up
# Error: Cannot connect to the Docker daemon
```

### Root Cause
You have `docker compose` command installed but Podman as the container engine. The `docker compose` command tries to connect to Docker daemon which doesn't exist.

### Solution
**Use Kubernetes instead of Docker Compose:**
```bash
./deploy-podman.sh
```

**OR install podman-compose:**
```bash
# macOS
brew install podman-compose

# Then use podman-compose instead
cd docker-compose
podman-compose up --build
```

---

## Issue 5: Minikube DNS Timeout During Build

### Symptoms
```bash
minikube ssh -- docker build ...
# Error: dial tcp: lookup registry-1.docker.io... i/o timeout
```

### Root Cause
Minikube's internal Docker daemon can't reach Docker Hub.

### Solution
**Build with Podman locally and load into Minikube:**
```bash
# This is what deploy-podman.sh does automatically
cd traceloop-sidecar
podman build -t traceloop-sidecar:latest .
podman save traceloop-sidecar:latest | minikube image load -
cd ..

cd ollama-simple-app
podman build -t ollama-simple-app:latest .
podman save ollama-simple-app:latest | minikube image load -
cd ..
```

---

## Issue 6: Wrong Image Names in Kubernetes

### Symptoms
```bash
kubectl describe pod <pod-name> -n openllmetry-demo
# Shows: Failed to pull image "traceloop-sidecar:latest"
# But: minikube image ls shows "localhost/traceloop-sidecar:latest"
```

### Root Cause
Podman tags images with `localhost/` prefix, but Kubernetes manifests don't include it.

### Solution
This is already fixed in the current manifests. If you encounter this:

```bash
# Verify image names in Minikube
minikube image ls | grep -E "(traceloop|ollama-simple)"

# Should show:
# localhost/traceloop-sidecar:latest
# localhost/ollama-simple-app:latest

# The k8s/05-ollama-simple-app.yaml now correctly references these
```

---

## Complete Deployment Checklist

Use this checklist to ensure proper deployment:

- [ ] **Prerequisites installed**
  ```bash
  podman --version
  minikube version
  kubectl version --client
  ```

- [ ] **Minikube running with sufficient resources**
  ```bash
  minikube start --memory=6144 --cpus=4
  ```

- [ ] **Images built with Podman**
  ```bash
  cd traceloop-sidecar && podman build -t traceloop-sidecar:latest . && cd ..
  cd ollama-simple-app && podman build -t ollama-simple-app:latest . && cd ..
  ```

- [ ] **Images loaded into Minikube**
  ```bash
  podman save traceloop-sidecar:latest | minikube image load -
  podman save ollama-simple-app:latest | minikube image load -
  ```

- [ ] **Public images loaded**
  ```bash
  ./fix-podman-images.sh
  # OR manually pull and load ollama, otel-collector, jaeger
  ```

- [ ] **Deployed to Kubernetes**
  ```bash
  kubectl apply -f k8s/
  ```

- [ ] **Pods running**
  ```bash
  kubectl get pods -n openllmetry-demo
  # All should show Running (wait 5-10 min for model download)
  ```

- [ ] **Services accessible**
  ```bash
  kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080
  kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686
  ```

- [ ] **Application working**
  ```bash
  curl http://localhost:8080/health
  curl -X POST http://localhost:8080/chat \
    -H "Content-Type: application/json" \
    -d '{"prompt": "What is OpenTelemetry?"}'
  ```

---

## Quick Commands Reference

### Check Status
```bash
# Minikube
minikube status

# Pods
kubectl get pods -n openllmetry-demo

# Images in Minikube
minikube image ls | grep -E "(traceloop|ollama|otel|jaeger)"

# Running Podman containers
podman ps
```

### Cleanup
```bash
# Stop standalone containers
podman stop $(podman ps -q)
podman rm $(podman ps -aq)

# Delete Kubernetes deployment
kubectl delete -f k8s/

# Stop Minikube
minikube stop
```

### Logs
```bash
# Kubernetes logs
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f
kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f

# Podman logs (if running standalone - not recommended)
podman logs -f <container-name>
```

---

## Automated Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `./deploy-podman.sh` | Complete automated deployment | First time setup or clean deployment |
| `./fix-podman-images.sh` | Fix image issues in existing deployment | When pods show ImagePullBackOff |
| `./check-status.sh` | Check deployment status | Monitor deployment progress |
| `./stop-all.sh` | Stop and cleanup | When done testing |

---

## Getting Help

If you encounter issues not covered here:

1. **Check pod status and events:**
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
   minikube image ls
   ```

4. **Check services:**
   ```bash
   kubectl get svc -n openllmetry-demo
   ```

5. **Review documentation:**
   - [PODMAN-USERS.md](PODMAN-USERS.md) - Complete Podman guide
   - [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - General troubleshooting
   - [DEPLOYMENT.md](DEPLOYMENT.md) - Detailed deployment guide

---

**Last Updated:** 2026-01-02