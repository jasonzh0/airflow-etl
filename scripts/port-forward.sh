#!/bin/bash
# Port forward to Airflow webserver
# This script sets up port forwarding to access the Airflow UI locally

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="airflow"
RELEASE_NAME="airflow"
LOCAL_PORT=8080

echo -e "${BLUE}Setting up port forwarding to Airflow API server...${NC}"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Namespace '$NAMESPACE' does not exist${NC}"
    echo "Deploy Airflow first with: ./scripts/deploy-airflow.sh"
    exit 1
fi

# Get API server service name (Airflow 3 uses api-server instead of webserver)
API_SERVICE="${RELEASE_NAME}-api-server"
if ! kubectl get svc "$API_SERVICE" -n "$NAMESPACE" &> /dev/null; then
    echo -e "${RED}Error: Service '$API_SERVICE' not found in namespace '$NAMESPACE'${NC}"
    echo "Make sure Airflow is deployed"
    exit 1
fi

# Check if port is already in use
if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${YELLOW}Port $LOCAL_PORT is already in use${NC}"
    read -p "Kill existing process and continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti:$LOCAL_PORT | xargs kill -9 2>/dev/null || true
        sleep 1
    else
        echo "Port forwarding cancelled"
        exit 0
    fi
fi

echo -e "${BLUE}Forwarding local port $LOCAL_PORT to Airflow API server...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop port forwarding${NC}"
echo ""
echo -e "${GREEN}Access Airflow UI at: http://localhost:$LOCAL_PORT${NC}"
echo ""

# Port forward
kubectl port-forward \
    -n "$NAMESPACE" \
    svc/"$API_SERVICE" \
    $LOCAL_PORT:8080

