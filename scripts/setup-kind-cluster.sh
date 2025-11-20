#!/bin/bash
# Setup kind cluster for Airflow
# This script creates a kind cluster named "airflow-cluster"

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CLUSTER_NAME="airflow-cluster"

echo -e "${BLUE}Setting up kind cluster: $CLUSTER_NAME${NC}"
echo ""

# Check if kind is installed
if ! command -v kind &> /dev/null; then
    echo -e "${RED}Error: kind is not installed${NC}"
    echo "Run ./scripts/check-prerequisites.sh first"
    exit 1
fi

# Check if cluster already exists
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}Cluster '$CLUSTER_NAME' already exists${NC}"
    read -p "Do you want to delete and recreate it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deleting existing cluster...${NC}"
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo -e "${GREEN}Using existing cluster${NC}"
        exit 0
    fi
fi

# Create kind cluster configuration
echo -e "${BLUE}Creating kind cluster configuration...${NC}"
cat > /tmp/kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

# Create the cluster
echo -e "${BLUE}Creating kind cluster...${NC}"
kind create cluster --name "$CLUSTER_NAME" --config /tmp/kind-config.yaml

# Clean up temp config
rm -f /tmp/kind-config.yaml

# Wait for cluster to be ready
echo -e "${BLUE}Waiting for cluster to be ready...${NC}"
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Set kubectl context
kubectl config use-context "kind-${CLUSTER_NAME}"

# Verify cluster is running
echo -e "${BLUE}Verifying cluster status...${NC}"
kubectl cluster-info

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Kind cluster '$CLUSTER_NAME' is ready!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Cluster context: kind-${CLUSTER_NAME}"
echo "To use this cluster: kubectl config use-context kind-${CLUSTER_NAME}"
echo ""

