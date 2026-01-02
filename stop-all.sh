#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Stop All Services"
echo "================================================"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect running environments
DOCKER_RUNNING=false
K8S_RUNNING=false

# Check Docker Compose
if command_exists docker-compose || command_exists docker; then
    if [ -f "docker-compose/docker-compose.yaml" ]; then
        cd docker-compose
        if docker-compose ps 2>/dev/null | grep -q "Up"; then
            DOCKER_RUNNING=true
        fi
        cd ..
    fi
fi

# Check Kubernetes
if command_exists kubectl; then
    if kubectl get namespace openllmetry-demo >/dev/null 2>&1; then
        K8S_RUNNING=true
    fi
fi

# If nothing is running
if [ "$DOCKER_RUNNING" = false ] && [ "$K8S_RUNNING" = false ]; then
    echo "No running deployments found."
    echo ""
    echo "Checked for:"
    echo "  - Docker Compose services"
    echo "  - Kubernetes namespace: openllmetry-demo"
    echo ""
    exit 0
fi

# Show menu
echo "Detected running deployments:"
echo ""
if [ "$DOCKER_RUNNING" = true ]; then
    echo "  ✓ Docker Compose"
fi
if [ "$K8S_RUNNING" = true ]; then
    echo "  ✓ Kubernetes (openllmetry-demo namespace)"
fi
echo ""
echo "Select what to stop:"
echo ""
echo "1) Docker Compose only"
echo "2) Kubernetes only"
echo "3) Both Docker Compose and Kubernetes"
echo "4) Exit (don't stop anything)"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        if [ "$DOCKER_RUNNING" = false ]; then
            echo "Docker Compose is not running"
            exit 0
        fi
        
        echo ""
        echo "Stopping Docker Compose services..."
        echo "================================================"
        echo ""
        
        cd docker-compose
        
        read -p "Remove volumes (including downloaded models)? [y/N]: " remove_volumes
        
        if [[ $remove_volumes =~ ^[Yy]$ ]]; then
            echo "Stopping services and removing volumes..."
            docker-compose down -v
            echo ""
            echo "✓ Services stopped and volumes removed"
        else
            echo "Stopping services (keeping volumes)..."
            docker-compose down
            echo ""
            echo "✓ Services stopped (volumes preserved)"
        fi
        
        cd ..
        ;;
        
    2)
        if [ "$K8S_RUNNING" = false ]; then
            echo "Kubernetes deployment is not running"
            exit 0
        fi
        
        echo ""
        echo "Stopping Kubernetes deployment..."
        echo "================================================"
        echo ""
        
        echo "Deleting namespace: openllmetry-demo"
        kubectl delete namespace openllmetry-demo --ignore-not-found=true
        
        echo ""
        echo "✓ Kubernetes deployment stopped"
        echo ""
        
        read -p "Stop Minikube cluster? [y/N]: " stop_minikube
        
        if [[ $stop_minikube =~ ^[Yy]$ ]]; then
            if command_exists minikube; then
                echo "Stopping Minikube..."
                minikube stop
                echo ""
                echo "✓ Minikube stopped"
                echo ""
                echo "To delete the Minikube cluster completely, run:"
                echo "  minikube delete"
            fi
        fi
        ;;
        
    3)
        echo ""
        echo "Stopping all deployments..."
        echo "================================================"
        echo ""
        
        # Stop Docker Compose
        if [ "$DOCKER_RUNNING" = true ]; then
            echo "Stopping Docker Compose services..."
            cd docker-compose
            
            read -p "Remove Docker volumes (including downloaded models)? [y/N]: " remove_volumes
            
            if [[ $remove_volumes =~ ^[Yy]$ ]]; then
                docker-compose down -v
                echo "✓ Docker Compose stopped (volumes removed)"
            else
                docker-compose down
                echo "✓ Docker Compose stopped (volumes preserved)"
            fi
            
            cd ..
            echo ""
        fi
        
        # Stop Kubernetes
        if [ "$K8S_RUNNING" = true ]; then
            echo "Stopping Kubernetes deployment..."
            kubectl delete namespace openllmetry-demo --ignore-not-found=true
            echo "✓ Kubernetes deployment stopped"
            echo ""
            
            read -p "Stop Minikube cluster? [y/N]: " stop_minikube
            
            if [[ $stop_minikube =~ ^[Yy]$ ]]; then
                if command_exists minikube; then
                    echo "Stopping Minikube..."
                    minikube stop
                    echo "✓ Minikube stopped"
                    echo ""
                    echo "To delete the Minikube cluster completely, run:"
                    echo "  minikube delete"
                fi
            fi
        fi
        
        echo ""
        echo "✓ All deployments stopped"
        ;;
        
    4)
        echo "Exiting without stopping anything..."
        exit 0
        ;;
        
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac

echo ""
echo "================================================"
echo "Cleanup Complete!"
echo "================================================"
echo ""
echo "To start services again, run:"
echo "  ./start-all.sh"
echo ""

# Made with Bob
