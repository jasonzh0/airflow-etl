#!/bin/bash
# Start Airflow on Kubernetes
# This script sets up the kind cluster and deploys Airflow

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Starting Airflow on Kubernetes${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"
if ! ./scripts/check-prerequisites.sh; then
    echo -e "${RED}Prerequisites check failed${NC}"
    exit 1
fi
echo ""

# Step 2: Setup kind cluster
echo -e "${BLUE}Step 2: Setting up kind cluster...${NC}"
./scripts/setup-kind-cluster.sh
echo ""

# Step 3: Deploy Airflow
echo -e "${BLUE}Step 3: Deploying Airflow...${NC}"
./scripts/deploy-airflow.sh
echo ""

# Step 4: Setup port forwarding in background
echo -e "${BLUE}Step 4: Setting up port forwarding...${NC}"
echo -e "${YELLOW}Note: Port forwarding will run in the background${NC}"
echo -e "${YELLOW}To stop it, run: pkill -f 'kubectl.*port-forward.*airflow'${NC}"
./scripts/port-forward.sh &
sleep 3

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Airflow is starting!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Access the Airflow UI at:${NC}"
echo -e "${GREEN}  http://localhost:8080${NC}"
echo ""
echo -e "${BLUE}Default credentials:${NC}"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo -e "${BLUE}To check status:${NC}"
echo "  ./scripts/status.sh"
echo ""
echo -e "${BLUE}To stop Airflow:${NC}"
echo "  ./scripts/stop-airflow.sh"
echo ""

