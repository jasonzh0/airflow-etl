#!/bin/bash
# Stop Airflow on Kubernetes
# This script stops port forwarding and optionally deletes the Airflow deployment

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

echo -e "${BLUE}Stopping Airflow...${NC}"
echo ""

# Stop port forwarding
echo -e "${BLUE}Stopping port forwarding...${NC}"
if pgrep -f "kubectl.*port-forward.*airflow" > /dev/null; then
    pkill -f "kubectl.*port-forward.*airflow"
    echo -e "${GREEN}Port forwarding stopped${NC}"
else
    echo -e "${YELLOW}No port forwarding process found${NC}"
fi
echo ""

# Ask what to do with the deployment
echo "What would you like to do?"
echo "  1) Keep Airflow deployment (just stop port forwarding)"
echo "  2) Delete Airflow deployment (keep cluster)"
echo "  3) Delete everything (Airflow + cluster)"
echo ""
read -p "Enter choice [1-3] (default: 1): " choice
choice=${choice:-1}

case $choice in
    1)
        echo -e "${GREEN}Keeping Airflow deployment${NC}"
        echo "You can restart port forwarding with: ./scripts/port-forward.sh"
        ;;
    2)
        echo -e "${BLUE}Deleting Airflow deployment...${NC}"
        if helm list -n "$NAMESPACE" | grep -q "^${RELEASE_NAME}"; then
            helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
            echo -e "${GREEN}Airflow deployment deleted${NC}"
        else
            echo -e "${YELLOW}Airflow deployment not found${NC}"
        fi
        
        # Optionally delete namespace
        read -p "Delete namespace '$NAMESPACE'? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kubectl delete namespace "$NAMESPACE" || true
            echo -e "${GREEN}Namespace deleted${NC}"
        fi
        ;;
    3)
        echo -e "${BLUE}Deleting Airflow deployment...${NC}"
        if helm list -n "$NAMESPACE" | grep -q "^${RELEASE_NAME}"; then
            helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true
        fi
        kubectl delete namespace "$NAMESPACE" || true
        
        echo -e "${BLUE}Deleting kind cluster...${NC}"
        if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
            kind delete cluster --name "$CLUSTER_NAME"
            echo -e "${GREEN}Kind cluster deleted${NC}"
        else
            echo -e "${YELLOW}Kind cluster not found${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Stopped!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

