#!/bin/bash
# Complete cleanup of Airflow Kubernetes setup
# This script removes the Helm release, namespace, and kind cluster

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

RELEASE_NAME="airflow"
NAMESPACE="airflow"
CLUSTER_NAME="airflow-cluster"

echo -e "${RED}========================================${NC}"
echo -e "${RED}Complete Cleanup${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}This will delete:${NC}"
echo "  - Airflow Helm release"
echo "  - Kubernetes namespace '$NAMESPACE'"
echo "  - Kind cluster '$CLUSTER_NAME'"
echo "  - All associated resources and data"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cleanup cancelled"
    exit 0
fi

echo ""

# Stop port forwarding
echo -e "${BLUE}Stopping port forwarding...${NC}"
pkill -f "kubectl.*port-forward.*airflow" 2>/dev/null || true
echo -e "${GREEN}Port forwarding stopped${NC}"
echo ""

# Delete Helm release
echo -e "${BLUE}Deleting Helm release...${NC}"
if helm list -n "$NAMESPACE" 2>/dev/null | grep -q "^${RELEASE_NAME}"; then
    helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
    echo -e "${GREEN}Helm release deleted${NC}"
else
    echo -e "${YELLOW}Helm release not found${NC}"
fi
echo ""

# Delete namespace
echo -e "${BLUE}Deleting namespace...${NC}"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    kubectl delete namespace "$NAMESPACE" || true
    echo -e "${GREEN}Namespace deleted${NC}"
else
    echo -e "${YELLOW}Namespace not found${NC}"
fi
echo ""

# Delete kind cluster
echo -e "${BLUE}Deleting kind cluster...${NC}"
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    kind delete cluster --name "$CLUSTER_NAME"
    echo -e "${GREEN}Kind cluster deleted${NC}"
else
    echo -e "${YELLOW}Kind cluster not found${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

