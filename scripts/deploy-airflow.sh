#!/bin/bash
# Deploy Airflow using Helm
# This script adds the Airflow Helm repo and deploys Airflow to the cluster

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RELEASE_NAME="airflow"
NAMESPACE="airflow"
HELM_REPO="apache-airflow"
HELM_REPO_URL="https://airflow.apache.org"
VALUES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/helm/values.yaml"

echo -e "${BLUE}Deploying Airflow to Kubernetes...${NC}"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
    echo "Make sure you have a Kubernetes cluster running"
    exit 1
fi

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: Helm is not installed${NC}"
    echo "Run ./scripts/check-prerequisites.sh first"
    exit 1
fi

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo -e "${RED}Error: Values file not found at $VALUES_FILE${NC}"
    exit 1
fi

# Add Helm repository
echo -e "${BLUE}Adding Apache Airflow Helm repository...${NC}"
if helm repo list | grep -q "^${HELM_REPO}"; then
    echo -e "${YELLOW}Repository already exists, updating...${NC}"
    helm repo update "$HELM_REPO"
else
    helm repo add "$HELM_REPO" "$HELM_REPO_URL"
    helm repo update
fi
echo ""

# Create namespace if it doesn't exist
echo -e "${BLUE}Creating namespace '$NAMESPACE'...${NC}"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Namespace '$NAMESPACE' already exists${NC}"
else
    kubectl create namespace "$NAMESPACE"
    echo -e "${GREEN}Namespace '$NAMESPACE' created${NC}"
fi
echo ""

# Check if release already exists
if helm list -n "$NAMESPACE" | grep -q "^${RELEASE_NAME}"; then
    echo -e "${YELLOW}Release '$RELEASE_NAME' already exists in namespace '$NAMESPACE'${NC}"
    read -p "Do you want to upgrade it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled"
        exit 0
    fi
    ACTION="upgrade"
else
    ACTION="install"
fi

# Deploy Airflow
if [ "$ACTION" == "install" ]; then
    echo -e "${BLUE}Installing Airflow...${NC}"
    helm install "$RELEASE_NAME" "$HELM_REPO/airflow" \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout 10m
else
    echo -e "${BLUE}Upgrading Airflow...${NC}"
    helm upgrade "$RELEASE_NAME" "$HELM_REPO/airflow" \
        --namespace "$NAMESPACE" \
        --values "$VALUES_FILE" \
        --wait \
        --timeout 10m
fi

echo ""

# Wait for all pods to be ready
echo -e "${BLUE}Waiting for all pods to be ready...${NC}"
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=600s || {
    echo -e "${YELLOW}Some pods may still be starting. Check status with: kubectl get pods -n $NAMESPACE${NC}"
}

echo ""

# Display deployment status
echo -e "${BLUE}Deployment status:${NC}"
kubectl get pods -n "$NAMESPACE"
echo ""

# Get service information
echo -e "${BLUE}Service information:${NC}"
kubectl get svc -n "$NAMESPACE"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Airflow deployment completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo ""
echo -e "${BLUE}To access the Airflow UI:${NC}"
echo "  1. Run: ./scripts/port-forward.sh"
echo "  2. Open: http://localhost:8080"
echo ""
echo -e "${BLUE}Default credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo "  Check status: ./scripts/status.sh"
echo "  View pods: kubectl get pods -n $NAMESPACE"
echo "  View logs: kubectl logs -n $NAMESPACE <pod-name>"
echo ""

