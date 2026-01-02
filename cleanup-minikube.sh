#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Cleanup"
echo "================================================"
echo ""

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    exit 1
fi

echo "Deleting OpenLLMetry namespace and all resources..."
kubectl delete namespace openllmetry-demo --ignore-not-found=true

echo ""
echo "Cleanup complete!"
echo ""
echo "To stop Minikube completely, run:"
echo "  minikube stop"
echo ""
echo "To delete the Minikube cluster, run:"
echo "  minikube delete"
echo ""

# Made with Bob
