#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Complete Image Cleanup"
echo "================================================"
echo ""
echo "⚠️  WARNING: This will delete ALL images related to this project!"
echo ""
echo "This includes:"
echo "  - Custom built images (traceloop-sidecar, ollama-simple-app)"
echo "  - Downloaded public images (ollama, otel-collector, jaeger)"
echo "  - Images in both Podman and Minikube"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Starting cleanup..."
echo ""

# Step 1: Stop and delete Kubernetes deployments
echo "Step 1: Cleaning up Kubernetes deployments..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if kubectl get namespace openllmetry-demo &> /dev/null; then
    echo "Deleting Kubernetes resources..."
    kubectl delete -f k8s/ --ignore-not-found=true
    echo "✅ Kubernetes resources deleted"
else
    echo "ℹ️  No Kubernetes resources found"
fi
echo ""

# Step 2: Remove images from Minikube
echo "Step 2: Removing images from Minikube..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if minikube status &> /dev/null; then
    echo "Removing project images from Minikube..."
    
    # List of images to remove
    IMAGES=(
        "localhost/traceloop-sidecar:latest"
        "localhost/ollama-simple-app:latest"
        "docker.io/ollama/ollama:latest"
        "docker.io/otel/opentelemetry-collector-contrib:0.93.0"
        "docker.io/jaegertracing/all-in-one:latest"
        "ollama/ollama:latest"
        "otel/opentelemetry-collector-contrib:0.93.0"
        "jaegertracing/all-in-one:latest"
    )
    
    for img in "${IMAGES[@]}"; do
        if minikube image ls | grep -q "$img"; then
            echo "  Removing: $img"
            minikube image rm "$img" 2>/dev/null || true
        fi
    done
    
    echo "✅ Minikube images cleaned"
else
    echo "ℹ️  Minikube not running, skipping Minikube cleanup"
fi
echo ""

# Step 3: Remove images from Podman
echo "Step 3: Removing images from Podman..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v podman &> /dev/null; then
    echo "Removing project images from Podman..."
    
    # Remove custom built images
    if podman images | grep -q "localhost/traceloop-sidecar"; then
        echo "  Removing: localhost/traceloop-sidecar:latest"
        podman rmi localhost/traceloop-sidecar:latest 2>/dev/null || true
    fi
    
    if podman images | grep -q "localhost/ollama-simple-app"; then
        echo "  Removing: localhost/ollama-simple-app:latest"
        podman rmi localhost/ollama-simple-app:latest 2>/dev/null || true
    fi
    
    # Remove public images
    if podman images | grep -q "docker.io/ollama/ollama"; then
        echo "  Removing: docker.io/ollama/ollama:latest"
        podman rmi docker.io/ollama/ollama:latest 2>/dev/null || true
    fi
    
    if podman images | grep -q "docker.io/otel/opentelemetry-collector-contrib"; then
        echo "  Removing: docker.io/otel/opentelemetry-collector-contrib:0.93.0"
        podman rmi docker.io/otel/opentelemetry-collector-contrib:0.93.0 2>/dev/null || true
    fi
    
    if podman images | grep -q "docker.io/jaegertracing/all-in-one"; then
        echo "  Removing: docker.io/jaegertracing/all-in-one:latest"
        podman rmi docker.io/jaegertracing/all-in-one:latest 2>/dev/null || true
    fi
    
    echo "✅ Podman images cleaned"
else
    echo "ℹ️  Podman not found, skipping Podman cleanup"
fi
echo ""

# Step 4: Clean up temporary files
echo "Step 4: Cleaning up temporary files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ -f /tmp/ollama.tar ]; then
    echo "  Removing: /tmp/ollama.tar"
    rm -f /tmp/ollama.tar
fi

if [ -d ./logs ]; then
    echo "  Removing: ./logs directory"
    rm -rf ./logs
fi

echo "✅ Temporary files cleaned"
echo ""

# Step 5: Optional - Delete Minikube cluster
echo "Step 5: Minikube cluster cleanup (optional)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -p "Do you want to delete the entire Minikube cluster? (yes/no): " delete_minikube

if [ "$delete_minikube" = "yes" ]; then
    echo "Deleting Minikube cluster..."
    minikube delete
    echo "✅ Minikube cluster deleted"
else
    echo "ℹ️  Minikube cluster preserved"
fi
echo ""

# Summary
echo "================================================"
echo "✅ Cleanup Complete!"
echo "================================================"
echo ""
echo "Summary of cleaned items:"
echo "  ✅ Kubernetes deployments and services"
echo "  ✅ Custom built images (traceloop-sidecar, ollama-simple-app)"
echo "  ✅ Public images (ollama, otel-collector, jaeger)"
echo "  ✅ Temporary files"
if [ "$delete_minikube" = "yes" ]; then
    echo "  ✅ Minikube cluster"
fi
echo ""

# Show remaining images
echo "Remaining images in Podman:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v podman &> /dev/null; then
    podman images | head -10
    echo ""
    echo "Total images: $(podman images | tail -n +2 | wc -l)"
else
    echo "Podman not available"
fi
echo ""

if [ "$delete_minikube" != "yes" ] && minikube status &> /dev/null; then
    echo "Remaining images in Minikube:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    minikube image ls | grep -E "(traceloop|ollama|otel|jaeger)" || echo "No project images found"
    echo ""
fi

echo "To start fresh, run:"
echo "  ./deploy-podman.sh"
echo ""

# Made with Bob
