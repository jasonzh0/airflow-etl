#!/bin/bash

# Deploy Dog Breeds Database to Kubernetes
# This script deploys the PostgreSQL database to store dog breed data

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
K8S_DIR="$PROJECT_DIR/k8s/dog-breeds-db"

echo "=================================================="
echo "Dog Breeds Database Deployment"
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

echo "✅ Kind cluster found: airflow-cluster"
echo ""

# Set kubectl context to kind cluster
echo "Setting kubectl context to kind-airflow-cluster..."
kubectl config use-context kind-airflow-cluster

echo ""
echo "Deploying Dog Breeds Database..."
echo ""

# Apply Kubernetes manifests
echo "1️⃣  Creating namespace..."
kubectl apply -f "$K8S_DIR/01-namespace.yaml"

echo "2️⃣  Creating ConfigMap..."
kubectl apply -f "$K8S_DIR/02-configmap.yaml"

echo "3️⃣  Creating Secret..."
kubectl apply -f "$K8S_DIR/03-secret.yaml"

echo "4️⃣  Creating PersistentVolumeClaim..."
kubectl apply -f "$K8S_DIR/04-pvc.yaml"

echo "5️⃣  Creating Schema ConfigMap..."
kubectl apply -f "$K8S_DIR/05-schema-configmap.yaml"

echo "6️⃣  Creating Deployment..."
kubectl apply -f "$K8S_DIR/06-deployment.yaml"

echo "7️⃣  Creating Service..."
kubectl apply -f "$K8S_DIR/07-service.yaml"

echo ""
echo "Waiting for database to be ready..."
kubectl wait --for=condition=ready pod -l app=dog-breeds,component=database -n dog-breeds --timeout=300s

echo ""
echo "=================================================="
echo "✅ Dog Breeds Database Deployed Successfully!"
echo "=================================================="
echo ""
echo "Database Details:"
echo "  Namespace: dog-breeds"
echo "  Service: dog-breeds-db.dog-breeds.svc.cluster.local:5432"
echo "  NodePort (external): localhost:30432"
echo "  Database Name: dog_breeds_db"
echo "  Username: airflow"
echo "  Password: airflow"
echo ""
echo "Check status:"
echo "  kubectl get all -n dog-breeds"
echo ""
echo "View logs:"
echo "  kubectl logs -n dog-breeds -l app=dog-breeds,component=database"
echo ""
echo "Connect to database (from inside cluster):"
echo "  kubectl run -n dog-breeds psql-client --rm -it --image=postgres:16-alpine -- \\"
echo "    psql -h dog-breeds-db -U airflow -d dog_breeds_db"
echo ""
echo "Connect to database (from host via NodePort):"
echo "  psql -h localhost -p 30432 -U airflow -d dog_breeds_db"
echo ""

