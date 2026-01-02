#!/bin/bash

set -e

echo "================================================"
echo "OpenLLMetry SideCar - Log Viewer"
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

# Show menu
echo "Select log viewing option:"
echo ""
echo "1) View application logs (live)"
echo "2) View sidecar logs (live)"
echo "3) View collector logs (live)"
echo "4) View all logs (live)"
echo "5) View application log files (from ./logs directory)"
echo "6) Copy logs from container to local ./logs directory"
echo "7) Exit"
echo ""
read -p "Enter choice [1-7]: " choice

case $choice in
    1)
        echo ""
        echo "Viewing application logs (Ctrl+C to exit)..."
        echo "================================================"
        echo ""
        
        if [ "$K8S_RUNNING" = true ]; then
            kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c ollama-simple-app -f
        elif [ "$DOCKER_RUNNING" = true ]; then
            cd docker-compose
            docker-compose logs -f ollama-simple-app
        else
            echo "No running deployment found"
        fi
        ;;
        
    2)
        echo ""
        echo "Viewing sidecar logs (Ctrl+C to exit)..."
        echo "================================================"
        echo ""
        
        if [ "$K8S_RUNNING" = true ]; then
            kubectl logs -n openllmetry-demo -l app=ollama-simple-app -c traceloop-sidecar -f
        elif [ "$DOCKER_RUNNING" = true ]; then
            cd docker-compose
            docker-compose logs -f traceloop-sidecar
        else
            echo "No running deployment found"
        fi
        ;;
        
    3)
        echo ""
        echo "Viewing collector logs (Ctrl+C to exit)..."
        echo "================================================"
        echo ""
        
        if [ "$K8S_RUNNING" = true ]; then
            kubectl logs -n openllmetry-demo -l app=otel-collector -f
        elif [ "$DOCKER_RUNNING" = true ]; then
            cd docker-compose
            docker-compose logs -f otel-collector
        else
            echo "No running deployment found"
        fi
        ;;
        
    4)
        echo ""
        echo "Viewing all logs (Ctrl+C to exit)..."
        echo "================================================"
        echo ""
        
        if [ "$K8S_RUNNING" = true ]; then
            kubectl logs -n openllmetry-demo -l app=ollama-simple-app -f --all-containers=true
        elif [ "$DOCKER_RUNNING" = true ]; then
            cd docker-compose
            docker-compose logs -f
        else
            echo "No running deployment found"
        fi
        ;;
        
    5)
        echo ""
        echo "Application log files in ./logs directory:"
        echo "================================================"
        echo ""
        
        if [ -d "logs" ]; then
            ls -lh logs/
            echo ""
            echo "Select a log file to view (or press Enter to exit):"
            read -p "Filename: " logfile
            
            if [ -n "$logfile" ] && [ -f "logs/$logfile" ]; then
                echo ""
                echo "Viewing logs/$logfile (press 'q' to exit):"
                echo "================================================"
                less logs/$logfile
            fi
        else
            echo "No logs directory found. Logs may be inside containers."
            echo "Use option 6 to copy logs from containers."
        fi
        ;;
        
    6)
        echo ""
        echo "Copying logs from container..."
        echo "================================================"
        echo ""
        
        # Create local logs directory
        mkdir -p logs
        
        if [ "$K8S_RUNNING" = true ]; then
            POD=$(kubectl get pods -n openllmetry-demo -l app=ollama-simple-app -o jsonpath='{.items[0].metadata.name}')
            
            if [ -n "$POD" ]; then
                echo "Copying logs from pod: $POD"
                kubectl cp -n openllmetry-demo "$POD:/app/logs" ./logs -c ollama-simple-app 2>/dev/null || \
                    echo "Note: Logs directory may not exist in container yet (no requests processed)"
                
                echo ""
                echo "Logs copied to ./logs directory"
                ls -lh logs/
            else
                echo "No pods found"
            fi
            
        elif [ "$DOCKER_RUNNING" = true ]; then
            CONTAINER=$(docker ps --filter "name=ollama-simple-app" --format "{{.Names}}" | head -1)
            
            if [ -n "$CONTAINER" ]; then
                echo "Copying logs from container: $CONTAINER"
                docker cp "$CONTAINER:/app/logs/." ./logs/ 2>/dev/null || \
                    echo "Note: Logs directory may not exist in container yet (no requests processed)"
                
                echo ""
                echo "Logs copied to ./logs directory"
                ls -lh logs/
            else
                echo "No containers found"
            fi
        else
            echo "No running deployment found"
        fi
        ;;
        
    7)
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""

# Made with Bob
