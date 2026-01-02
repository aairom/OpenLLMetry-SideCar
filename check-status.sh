#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Status Check"
echo "================================================"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect environment
DOCKER_RUNNING=false
K8S_RUNNING=false

if command_exists docker-compose || command_exists docker; then
    if [ -f "docker-compose/docker-compose.yaml" ]; then
        cd docker-compose 2>/dev/null || true
        if docker-compose ps 2>/dev/null | grep -q "Up"; then
            DOCKER_RUNNING=true
        fi
        cd .. 2>/dev/null || true
    fi
fi

if command_exists kubectl; then
    if kubectl get namespace openllmetry-demo >/dev/null 2>&1; then
        K8S_RUNNING=true
    fi
fi

if [ "$DOCKER_RUNNING" = false ] && [ "$K8S_RUNNING" = false ]; then
    echo "❌ No running deployments found"
    echo ""
    echo "Start a deployment with:"
    echo "  ./start-all.sh"
    echo ""
    exit 0
fi

# Docker Compose Status
if [ "$DOCKER_RUNNING" = true ]; then
    echo "🐳 Docker Compose Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    cd docker-compose
    docker-compose ps
    cd ..
    echo ""
    echo "Access URLs:"
    echo "  Jaeger UI:       http://localhost:16686"
    echo "  Application API: http://localhost:8080"
    echo ""
    echo "Test Application:"
    echo "  curl http://localhost:8080/health"
    echo ""
fi

# Kubernetes Status
if [ "$K8S_RUNNING" = true ]; then
    echo "☸️  Kubernetes Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Get pod status
    echo "Pods:"
    kubectl get pods -n openllmetry-demo
    echo ""
    
    # Check if all pods are ready
    TOTAL_PODS=$(kubectl get pods -n openllmetry-demo --no-headers 2>/dev/null | wc -l | tr -d ' ')
    READY_PODS=$(kubectl get pods -n openllmetry-demo --no-headers 2>/dev/null | grep "Running" | wc -l | tr -d ' ')
    
    if [ "$TOTAL_PODS" -eq 0 ]; then
        echo "❌ No pods found. Run: ./start-all.sh"
        exit 0
    fi
    
    echo "Status: $READY_PODS/$TOTAL_PODS pods running"
    echo ""
    
    # Check specific pod statuses
    OLLAMA_STATUS=$(kubectl get pods -n openllmetry-demo -l app=ollama -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    COLLECTOR_STATUS=$(kubectl get pods -n openllmetry-demo -l app=otel-collector -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    JAEGER_STATUS=$(kubectl get pods -n openllmetry-demo -l app=jaeger -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    APP_STATUS=$(kubectl get pods -n openllmetry-demo -l app=ollama-simple-app -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
    
    echo "Component Status:"
    echo "  Ollama:          $OLLAMA_STATUS"
    echo "  OTel Collector:  $COLLECTOR_STATUS"
    echo "  Jaeger:          $JAEGER_STATUS"
    echo "  Simple App:      $APP_STATUS"
    echo ""
    
    if [ "$READY_PODS" -lt "$TOTAL_PODS" ]; then
        echo "⏳ Deployment in progress..."
        echo ""
        echo "Waiting for:"
        kubectl get pods -n openllmetry-demo --no-headers | grep -v "Running" | awk '{print "  - " $1 " (" $3 ")"}'
        echo ""
        echo "This may take 5-10 minutes for model download."
        echo ""
        echo "Watch progress:"
        echo "  kubectl get pods -n openllmetry-demo -w"
        echo ""
        echo "Check logs:"
        echo "  ./view-logs.sh"
        echo ""
    else
        echo "✅ All pods are running!"
        echo ""
        
        MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "unknown")
        
        echo "Access URLs:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Jaeger UI:"
        echo "  NodePort:     http://${MINIKUBE_IP}:30686"
        echo "  Port Forward: kubectl port-forward -n openllmetry-demo svc/jaeger 16686:16686"
        echo "                Then: http://localhost:16686"
        echo ""
        echo "Application API:"
        echo "  Port Forward: kubectl port-forward -n openllmetry-demo svc/ollama-simple-app 8080:8080"
        echo "                Then: http://localhost:8080"
        echo ""
        echo "Test Application (after port-forward):"
        echo "  curl http://localhost:8080/health"
        echo ""
        echo "  curl -X POST http://localhost:8080/chat \\"
        echo "    -H 'Content-Type: application/json' \\"
        echo "    -d '{\"prompt\": \"What is OpenTelemetry?\"}'"
        echo ""
    fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For more details, see:"
echo "  ./view-logs.sh           # View logs"
echo "  QUICK-REFERENCE.md       # URLs and commands"
echo "  TESTING.md               # Testing guide"
echo ""

# Made with Bob
