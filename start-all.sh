#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Start All Services"
echo "================================================"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect environment
if command_exists docker-compose || command_exists docker; then
    HAS_DOCKER=true
else
    HAS_DOCKER=false
fi

if command_exists kubectl && command_exists minikube; then
    HAS_K8S=true
else
    HAS_K8S=false
fi

# Show menu
echo "Select deployment environment:"
echo ""
echo "1) Docker Compose (Local)"
echo "2) Kubernetes (Minikube)"
echo "3) Exit"
echo ""
read -p "Enter choice [1-3]: " choice

case $choice in
    1)
        if [ "$HAS_DOCKER" = false ]; then
            echo "Error: Docker is not installed"
            echo "Please install Docker: https://docs.docker.com/get-docker/"
            exit 1
        fi
        
        echo ""
        echo "Starting Docker Compose deployment..."
        echo "================================================"
        echo ""
        
        cd docker-compose
        
        echo "Building and starting all services..."
        docker-compose up --build -d
        
        echo ""
        echo "Waiting for services to be ready..."
        sleep 5
        
        echo ""
        echo "Service Status:"
        docker-compose ps
        
        echo ""
        echo "================================================"
        echo "✅ Docker Compose Deployment Started!"
        echo "================================================"
        echo ""
        echo "🌐 ACCESS URLS:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📊 Jaeger UI (Trace Visualization):"
        echo "   http://localhost:16686"
        echo "   → Select service: 'ollama-simple-app'"
        echo "   → Click 'Find Traces' to see LLM traces"
        echo ""
        echo "🤖 Application API:"
        echo "   http://localhost:8080"
        echo ""
        echo "   Health Check:"
        echo "   curl http://localhost:8080/health"
        echo ""
        echo "   Chat Request:"
        echo "   curl -X POST http://localhost:8080/chat \\"
        echo "     -H 'Content-Type: application/json' \\"
        echo "     -d '{\"prompt\": \"What is OpenTelemetry?\"}'"
        echo ""
        echo "🔧 Ollama API (Direct - bypasses sidecar):"
        echo "   http://localhost:11434"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📋 USEFUL COMMANDS:"
        echo ""
        echo "View Logs:"
        echo "  ./view-logs.sh                            # Interactive log viewer"
        echo "  docker-compose logs -f                    # All services"
        echo "  docker-compose logs -f ollama-simple-app  # Application only"
        echo ""
        echo "Check Status:"
        echo "  docker-compose ps                         # Service status"
        echo ""
        echo "Stop Services:"
        echo "  ./stop-all.sh                             # Interactive stop"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📖 Next Steps:"
        echo "  1. Open Jaeger UI: http://localhost:16686"
        echo "  2. Test the API with the curl command above"
        echo "  3. View traces in Jaeger (service: ollama-simple-app)"
        echo "  4. Check logs: ./view-logs.sh"
        echo ""
        ;;
        
    2)
        if [ "$HAS_K8S" = false ]; then
            echo "Error: Kubernetes tools not installed"
            echo "Please install:"
            echo "  - Minikube: https://minikube.sigs.k8s.io/docs/start/"
            echo "  - kubectl: https://kubernetes.io/docs/tasks/tools/"
            exit 1
        fi
        
        echo ""
        echo "Starting Kubernetes deployment..."
        echo "================================================"
        echo ""
        
        # Check if minikube is running
        if ! minikube status >/dev/null 2>&1; then
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
        
        echo "  - Building traceloop-sidecar..."
        cd traceloop-sidecar
        docker build -t traceloop-sidecar:latest . >/dev/null 2>&1
        cd ..
        
        echo "  - Building ollama-simple-app..."
        cd ollama-simple-app
        docker build -t ollama-simple-app:latest . >/dev/null 2>&1
        cd ..
        
        echo "  - Building ollama-app..."
        cd ollama-app
        docker build -t ollama-app:latest . >/dev/null 2>&1
        cd ..
        
        echo ""
        echo "Deploying to Kubernetes..."
        kubectl apply -f k8s/00-namespace.yaml
        kubectl apply -f k8s/01-otel-collector.yaml
        kubectl apply -f k8s/02-ollama.yaml
        kubectl apply -f k8s/04-jaeger.yaml
        kubectl apply -f k8s/05-ollama-simple-app.yaml
        
        echo ""
        echo "Waiting for pods to be ready (this may take several minutes)..."
        kubectl wait --for=condition=ready pod -l app=otel-collector -n openllmetry-demo --timeout=300s 2>/dev/null || true
        kubectl wait --for=condition=ready pod -l app=jaeger -n openllmetry-demo --timeout=300s 2>/dev/null || true
        kubectl wait --for=condition=ready pod -l app=ollama -n openllmetry-demo --timeout=300s 2>/dev/null || true
        
        MINIKUBE_IP=$(minikube ip)
        
        echo ""
        echo "================================================"
        echo "✅ Kubernetes Deployment Started!"
        echo "================================================"
        echo ""
        echo "⏳ IMPORTANT: Waiting for model download..."
        echo "   The ollama-simple-app pod will start after granite3 model"
        echo "   is downloaded (~2GB, takes 5-10 minutes)."
        echo ""
        echo "   Monitor progress:"
        echo "   kubectl get pods -n openllmetry-demo -w"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "🌐 ACCESS URLS (after pods are ready):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📊 Jaeger UI (Trace Visualization):"
        echo ""
        echo "   Method 1 - NodePort (Direct):"
        echo "   http://${MINIKUBE_IP}:30686"
        echo ""
        echo "   Method 2 - Port Forward (Recommended):"
        echo "   kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686"
        echo "   Then visit: http://localhost:16686"
        echo ""
        echo "   → Select service: 'ollama-simple-app'"
        echo "   → Click 'Find Traces' to see LLM traces"
        echo ""
        echo "🤖 Application API:"
        echo ""
        echo "   Port Forward:"
        echo "   kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080"
        echo "   Then access: http://localhost:8080"
        echo ""
        echo "   Health Check:"
        echo "   curl http://localhost:8080/health"
        echo ""
        echo "   Chat Request:"
        echo "   curl -X POST http://localhost:8080/chat \\"
        echo "     -H 'Content-Type: application/json' \\"
        echo "     -d '{\"prompt\": \"What is OpenTelemetry?\"}'"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📋 USEFUL COMMANDS:"
        echo ""
        echo "Check Pod Status:"
        echo "  kubectl get pods -n openllmetry-demo"
        echo "  kubectl get pods -n openllmetry-demo -w  # Watch mode"
        echo ""
        echo "View Logs:"
        echo "  ./view-logs.sh                           # Interactive log viewer"
        echo "  kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f"
        echo "  kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f"
        echo ""
        echo "Stop Services:"
        echo "  ./stop-all.sh                            # Interactive stop"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "📖 Next Steps:"
        echo "  1. Wait for pods to be ready (check with: kubectl get pods -n openllmetry-demo)"
        echo "  2. Port-forward Jaeger: kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686"
        echo "  3. Open Jaeger UI: http://localhost:16686"
        echo "  4. Port-forward App: kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080"
        echo "  5. Test the API with the curl command above"
        echo "  6. View traces in Jaeger (service: ollama-simple-app)"
        echo ""
        ;;
        
    3)
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

# Made with Bob
