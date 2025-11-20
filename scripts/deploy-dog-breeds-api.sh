#!/bin/bash

# Deploy Dog Breeds API to Kubernetes
# This script builds and deploys the FastAPI backend

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
API_DIR="$PROJECT_DIR/api"
K8S_DIR="$PROJECT_DIR/k8s/dog-breeds-api"

echo "=================================================="
echo "Dog Breeds API Deployment"
echo "=================================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

# Check if kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "airflow-cluster"; then
    echo "❌ Kind cluster 'airflow-cluster' not found."
    echo "Please run ./scripts/setup-kind-cluster.sh first."
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Set kubectl context to kind cluster
echo "Setting kubectl context to kind-airflow-cluster..."
kubectl config use-context kind-airflow-cluster

echo ""
echo "Building Docker image..."
echo ""

# Build Docker image
cd "$API_DIR"
docker build -t dog-breeds-api:latest .

echo ""
echo "Loading image into kind cluster..."
kind load docker-image dog-breeds-api:latest --name airflow-cluster

echo ""
echo "Deploying Dog Breeds API..."
echo ""

# Apply Kubernetes manifests
echo "1️⃣  Creating ConfigMap..."
kubectl apply -f "$K8S_DIR/01-configmap.yaml"

echo "2️⃣  Creating Deployment..."
kubectl apply -f "$K8S_DIR/02-deployment.yaml"

echo "3️⃣  Creating Service..."
kubectl apply -f "$K8S_DIR/03-service.yaml"

echo "4️⃣  Creating Ingress (optional)..."
kubectl apply -f "$K8S_DIR/04-ingress.yaml" || echo "⚠️  Ingress creation failed (NGINX Ingress Controller might not be installed)"

echo ""
echo "Waiting for API to be ready..."
kubectl wait --for=condition=ready pod -l app=dog-breeds,component=api -n dog-breeds --timeout=300s

echo ""
echo "=================================================="
echo "✅ Dog Breeds API Deployed Successfully!"
echo "=================================================="
echo ""
echo "API Details:"
echo "  Namespace: dog-breeds"
echo "  Service: dog-breeds-api.dog-breeds.svc.cluster.local:8000"
echo "  NodePort (external): http://localhost:30800"
echo ""
echo "API Endpoints:"
echo "  Health Check: http://localhost:30800/health"
echo "  API Docs: http://localhost:30800/docs"
echo "  Recent Breeds: http://localhost:30800/api/breeds/recent"
echo ""
echo "Check status:"
echo "  kubectl get all -n dog-breeds"
echo ""
echo "View logs:"
echo "  kubectl logs -n dog-breeds -l app=dog-breeds,component=api"
echo ""
echo "Test the API:"
echo "  curl http://localhost:30800/health"
echo "  curl http://localhost:30800/api/breeds/recent?limit=5"
echo ""

