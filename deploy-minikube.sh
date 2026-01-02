#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Minikube Deployment"
echo "================================================"
echo ""

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Error: minikube is not installed"
    echo "Please install minikube: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    echo "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if minikube is running
if ! minikube status &> /dev/null; then
    echo "Starting Minikube with 6GB RAM and 4 CPUs..."
    minikube start --memory=6144 --cpus=4
else
    echo "Minikube is already running"
fi

echo ""
echo "Setting Docker environment to use Minikube's Docker daemon..."
eval $(minikube docker-env)

echo ""
echo "Building container images..."

echo "Building traceloop-sidecar..."
cd traceloop-sidecar
docker build -t traceloop-sidecar:latest .
cd ..

echo "Building ollama-simple-app..."
cd ollama-simple-app
docker build -t ollama-simple-app:latest .
cd ..

echo "Building ollama-app (instrumented version)..."
cd ollama-app
docker build -t ollama-app:latest .
cd ..

echo ""
echo "Deploying to Kubernetes..."
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-otel-collector.yaml
kubectl apply -f k8s/02-ollama.yaml
kubectl apply -f k8s/04-jaeger.yaml
kubectl apply -f k8s/05-ollama-simple-app.yaml

echo ""
echo "Waiting for pods to be ready..."
echo "This may take several minutes as Ollama downloads the model..."
kubectl wait --for=condition=ready pod -l app=otel-collector -n openllmetry-demo --timeout=300s
kubectl wait --for=condition=ready pod -l app=jaeger -n openllmetry-demo --timeout=300s
kubectl wait --for=condition=ready pod -l app=ollama -n openllmetry-demo --timeout=300s

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Architecture:"
echo "  Ollama Simple App (no tracing code)"
echo "    ↓ (via localhost)"
echo "  TraceLoop Sidecar (adds tracing)"
echo "    ↓"
echo "  Ollama (LLM engine)"
echo ""
echo "  TraceLoop Sidecar → OTel Collector → Jaeger"
echo ""
echo "Access Jaeger UI:"
echo "  Method 1: http://$(minikube ip):30686"
echo "  Method 2: kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686"
echo "            Then visit: http://localhost:16686"
echo ""
echo "View logs:"
echo "  Simple App:        kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f"
echo "  TraceLoop Sidecar: kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f"
echo "  OTel Collector:    kubectl logs -n openllmetry-demo -l app=otel-collector -f"
echo ""
echo "Check pod status:"
echo "  kubectl get pods -n openllmetry-demo"
echo ""
echo "Note: The ollama-simple-app pod will start after the model is downloaded."
echo "      This may take 5-10 minutes depending on your connection."
echo ""
echo "In Jaeger UI, look for service: 'ollama-simple-app'"
echo ""

# Made with Bob
