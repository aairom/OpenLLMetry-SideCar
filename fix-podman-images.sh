#!/bin/bash

set -e

echo "================================================"
echo "Fix Podman Image References for Kubernetes"
echo "================================================"
echo ""

echo "This script will:"
echo "1. Pull missing public images (otel-collector, ollama, jaeger)"
echo "2. Load them into Minikube"
echo "3. Restart the deployment"
echo ""

# Check if ollama image is still downloading
if podman images | grep -q "ollama/ollama"; then
    echo "✅ Ollama image already available"
else
    echo "Pulling Ollama image (this may take a few minutes, ~2GB)..."
    podman pull ollama/ollama:latest
fi

echo ""
echo "Loading Ollama into Minikube..."
podman save ollama/ollama:latest | minikube image load -
echo "✅ Ollama loaded"
echo ""

echo "Pulling Jaeger..."
podman pull jaegertracing/all-in-one:latest
echo "Loading Jaeger into Minikube..."
podman save jaegertracing/all-in-one:latest | minikube image load -
echo "✅ Jaeger loaded"
echo ""

echo "Restarting deployments..."
kubectl rollout restart deployment/otel-collector -n openllmetry-demo
kubectl rollout restart deployment/ollama -n openllmetry-demo
kubectl rollout restart deployment/jaeger -n openllmetry-demo
kubectl rollout restart deployment/ollama-simple-app -n openllmetry-demo

echo ""
echo "✅ Images loaded and deployments restarted!"
echo ""
echo "Check status with:"
echo "  kubectl get pods -n openllmetry-demo"
echo ""
echo "Wait for all pods to be Running (5-10 minutes for model download)"
echo ""

# Made with Bob
