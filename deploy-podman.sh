#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Podman Deployment"
echo "================================================"
echo ""

# Check if podman is installed
if ! command -v podman &> /dev/null; then
    echo "❌ Error: Podman is not installed"
    echo "Please install Podman: https://podman.io/getting-started/installation"
    exit 1
fi

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Error: Minikube is not installed"
    echo "Please install Minikube: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

echo "✅ All required tools are installed"
echo ""

# Step 1: Start Minikube
echo "Step 1: Starting Minikube..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! minikube status &> /dev/null; then
    echo "Starting Minikube with 6GB RAM and 4 CPUs..."
    minikube start --memory=6144 --cpus=4
else
    echo "✅ Minikube is already running"
fi
echo ""

# Step 2: Build images with Podman
echo "Step 2: Building container images with Podman..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "This may take a few minutes..."
echo ""

echo "Building traceloop-sidecar..."
cd traceloop-sidecar
if podman build -t traceloop-sidecar:latest . ; then
    echo "✅ traceloop-sidecar built successfully"
else
    echo "❌ Failed to build traceloop-sidecar"
    echo "Check the error messages above"
    exit 1
fi
cd ..
echo ""

echo "Building ollama-simple-app..."
cd ollama-simple-app
if podman build -t ollama-simple-app:latest . ; then
    echo "✅ ollama-simple-app built successfully"
else
    echo "❌ Failed to build ollama-simple-app"
    echo "Check the error messages above"
    exit 1
fi
cd ..
echo ""

# Step 3: Load images into Minikube
echo "Step 3: Loading images into Minikube..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Loading traceloop-sidecar..."
if podman save traceloop-sidecar:latest | minikube image load - ; then
    echo "✅ traceloop-sidecar loaded into Minikube"
else
    echo "❌ Failed to load traceloop-sidecar"
    exit 1
fi
echo ""

echo "Loading ollama-simple-app..."
if podman save ollama-simple-app:latest | minikube image load - ; then
    echo "✅ ollama-simple-app loaded into Minikube"
else
    echo "❌ Failed to load ollama-simple-app"
    exit 1
fi
echo ""

# Step 4: Pull and load public images
echo "Step 4: Pulling and loading public images..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Pulling OpenTelemetry Collector..."
if podman pull otel/opentelemetry-collector-contrib:0.93.0 ; then
    echo "✅ OpenTelemetry Collector pulled"
    echo "Loading into Minikube..."
    if podman save otel/opentelemetry-collector-contrib:0.93.0 | minikube image load - ; then
        echo "✅ OpenTelemetry Collector loaded"
    else
        echo "❌ Failed to load OpenTelemetry Collector"
        exit 1
    fi
else
    echo "❌ Failed to pull OpenTelemetry Collector"
    exit 1
fi
echo ""

echo "Pulling Ollama (this may take a few minutes, ~2GB)..."
if podman pull ollama/ollama:latest ; then
    echo "✅ Ollama pulled"
    echo "Loading into Minikube..."
    if podman save ollama/ollama:latest | minikube image load - ; then
        echo "✅ Ollama loaded"
    else
        echo "❌ Failed to load Ollama"
        exit 1
    fi
else
    echo "❌ Failed to pull Ollama"
    exit 1
fi
echo ""

# Step 5: Deploy to Kubernetes
echo "Step 5: Deploying to Kubernetes..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl apply -f k8s/
echo ""

# Step 6: Wait for pods
echo "Step 6: Waiting for pods to be ready..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "This may take 5-10 minutes for model download..."
echo ""

kubectl wait --for=condition=ready pod -l app=otel-collector -n openllmetry-demo --timeout=300s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=jaeger -n openllmetry-demo --timeout=300s 2>/dev/null || true
kubectl wait --for=condition=ready pod -l app=ollama -n openllmetry-demo --timeout=600s 2>/dev/null || true

echo ""
echo "================================================"
echo "✅ Deployment Complete!"
echo "================================================"
echo ""

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)

echo "📊 Current Status:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
kubectl get pods -n openllmetry-demo
echo ""

echo "⏳ Note: The ollama-simple-app pod will start after the model is downloaded."
echo "   This may take 5-10 minutes. Monitor with:"
echo "   kubectl get pods -n openllmetry-demo -w"
echo ""

echo "🌐 Access URLs (after all pods are Running):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📊 Jaeger UI (Trace Visualization):"
echo "   NodePort:     http://${MINIKUBE_IP}:30686"
echo "   Port Forward: kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686"
echo "                 Then: http://localhost:16686"
echo ""
echo "🤖 Application API:"
echo "   Port Forward: kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080"
echo "                 Then: http://localhost:8080"
echo ""

echo "📋 Useful Commands:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Check Status:"
echo "  ./check-status.sh"
echo "  kubectl get pods -n openllmetry-demo"
echo ""
echo "View Logs:"
echo "  ./view-logs.sh"
echo "  kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f"
echo ""
echo "Port Forward (run in separate terminals):"
echo "  kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686"
echo "  kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080"
echo ""
echo "Test Application (after port-forward):"
echo "  curl http://localhost:8080/health"
echo ""
echo "Stop Services:"
echo "  ./stop-all.sh"
echo ""

echo "📖 Documentation:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PODMAN-USERS.md       - Complete Podman guide"
echo "  QUICK-REFERENCE.md    - Quick commands"
echo "  TROUBLESHOOTING.md    - Common issues"
echo ""

# Made with Bob
