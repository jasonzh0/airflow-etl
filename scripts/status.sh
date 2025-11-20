#!/bin/bash
# Check status of Airflow deployment and cluster
# This script displays the current status of all components

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="airflow"
RELEASE_NAME="airflow"
CLUSTER_NAME="airflow-cluster"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Airflow Kubernetes Status${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check kind cluster
echo -e "${BLUE}Kind Cluster:${NC}"
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${GREEN}✓${NC} Cluster '$CLUSTER_NAME' exists"
    if kubectl cluster-info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Cluster is accessible"
        kubectl cluster-info | head -n 1
    else
        echo -e "${RED}✗${NC} Cluster is not accessible"
    fi
else
    echo -e "${RED}✗${NC} Cluster '$CLUSTER_NAME' does not exist"
fi
echo ""

# Check namespace
echo -e "${BLUE}Namespace:${NC}"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${GREEN}✓${NC} Namespace '$NAMESPACE' exists"
else
    echo -e "${RED}✗${NC} Namespace '$NAMESPACE' does not exist"
    echo ""
    exit 0
fi
echo ""

# Check Helm release
echo -e "${BLUE}Helm Release:${NC}"
if helm list -n "$NAMESPACE" | grep -q "^${RELEASE_NAME}"; then
    echo -e "${GREEN}✓${NC} Release '$RELEASE_NAME' is deployed"
    helm list -n "$NAMESPACE" | grep "^${RELEASE_NAME}"
else
    echo -e "${RED}✗${NC} Release '$RELEASE_NAME' is not deployed"
fi
echo ""

# Check pods
echo -e "${BLUE}Pods:${NC}"
if kubectl get pods -n "$NAMESPACE" &> /dev/null; then
    kubectl get pods -n "$NAMESPACE"
    echo ""
    
    # Count ready vs not ready
    READY=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o True | wc -l | tr -d ' ')
    TOTAL=$(kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    NOT_READY=$((TOTAL - READY))
    
    if [ "$NOT_READY" -eq 0 ] && [ "$TOTAL" -gt 0 ]; then
        echo -e "${GREEN}✓${NC} All pods are ready ($READY/$TOTAL)"
    elif [ "$TOTAL" -gt 0 ]; then
        echo -e "${YELLOW}⚠${NC} Some pods are not ready ($READY/$TOTAL ready)"
    fi
else
    echo -e "${RED}✗${NC} Unable to get pod status"
fi
echo ""

# Check services
echo -e "${BLUE}Services:${NC}"
if kubectl get svc -n "$NAMESPACE" &> /dev/null; then
    kubectl get svc -n "$NAMESPACE"
else
    echo -e "${RED}✗${NC} Unable to get service status"
fi
echo ""

# Check port forwarding
echo -e "${BLUE}Port Forwarding:${NC}"
if pgrep -f "kubectl.*port-forward.*airflow" > /dev/null; then
    echo -e "${GREEN}✓${NC} Port forwarding is active"
    echo "  Access UI at: http://localhost:8080"
else
    echo -e "${YELLOW}⚠${NC} Port forwarding is not active"
    echo "  Run: ./scripts/port-forward.sh"
fi
echo ""

# Show recent pod events if there are issues
if [ "$NOT_READY" -gt 0 ] 2>/dev/null; then
    echo -e "${BLUE}Recent Events (for troubleshooting):${NC}"
    kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' | tail -n 5
    echo ""
fi

echo -e "${BLUE}========================================${NC}"

