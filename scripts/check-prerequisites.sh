#!/bin/bash
# Check prerequisites for Airflow Kubernetes setup
# This script verifies that all required tools are installed

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Checking prerequisites for Airflow Kubernetes setup...${NC}"
echo ""

ERRORS=0

# Function to check if a command exists
check_command() {
    local cmd=$1
    local install_hint=$2
    
    if command -v "$cmd" &> /dev/null; then
        local version
        version=$($cmd --version 2>&1 | head -n 1)
        echo -e "${GREEN}✓${NC} $cmd is installed: $version"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd is not installed"
        if [ -n "$install_hint" ]; then
            echo -e "  ${YELLOW}Install: $install_hint${NC}"
        fi
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

# Check Docker
echo "Checking Docker..."
if check_command "docker" "Visit https://docs.docker.com/get-docker/"; then
    # Check if Docker daemon is running
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker daemon is running"
    else
        echo -e "${RED}✗${NC} Docker daemon is not running"
        echo -e "  ${YELLOW}Start Docker Desktop or Docker daemon${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi
echo ""

# Check kubectl
echo "Checking kubectl..."
if check_command "kubectl" "Visit https://kubernetes.io/docs/tasks/tools/"; then
    # Check kubectl version (should be 1.30+ for Airflow Helm chart)
    KUBECTL_VERSION=$(kubectl version --client --short 2>&1 | sed 's/.*v\([0-9]*\)\..*/\1/')
    if [ -n "$KUBECTL_VERSION" ] && [ "$KUBECTL_VERSION" -ge 1 ]; then
        echo -e "${GREEN}✓${NC} kubectl version is compatible"
    fi
fi
echo ""

# Check kind
echo "Checking kind..."
if check_command "kind" "Run: brew install kind (macOS) or go install sigs.k8s.io/kind@v0.20.0"; then
    KIND_VERSION=$(kind --version 2>&1 | grep -oP 'v\d+\.\d+\.\d+' || echo "unknown")
    echo -e "${GREEN}✓${NC} kind version: $KIND_VERSION"
else
    echo -e "${YELLOW}Attempting to install kind...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            echo "Installing kind via Homebrew..."
            brew install kind
            if check_command "kind"; then
                ERRORS=$((ERRORS - 1))
            fi
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing kind via binary..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        if check_command "kind"; then
            ERRORS=$((ERRORS - 1))
        fi
    fi
fi
echo ""

# Check Helm
echo "Checking Helm..."
if check_command "helm" "Run: brew install helm (macOS) or visit https://helm.sh/docs/intro/install/"; then
    HELM_VERSION=$(helm version --short 2>&1 | grep -oP 'v\d+\.\d+' || echo "unknown")
    # Check if Helm version is 3.10+
    HELM_MAJOR=$(echo "$HELM_VERSION" | cut -d. -f1 | sed 's/v//')
    HELM_MINOR=$(echo "$HELM_VERSION" | cut -d. -f2)
    if [ -n "$HELM_MAJOR" ] && [ "$HELM_MAJOR" -ge 3 ] && [ -n "$HELM_MINOR" ] && [ "$HELM_MINOR" -ge 10 ]; then
        echo -e "${GREEN}✓${NC} Helm version 3.10+ is installed"
    else
        echo -e "${YELLOW}⚠${NC} Helm version should be 3.10+ (current: $HELM_VERSION)"
    fi
else
    echo -e "${YELLOW}Attempting to install Helm...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            echo "Installing Helm via Homebrew..."
            brew install helm
            if check_command "helm"; then
                ERRORS=$((ERRORS - 1))
            fi
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "Installing Helm via script..."
        curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        if check_command "helm"; then
            ERRORS=$((ERRORS - 1))
        fi
    fi
fi
echo ""

# Summary
echo -e "${BLUE}========================================${NC}"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All prerequisites are met!${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS prerequisite(s) missing or failed${NC}"
    echo -e "${YELLOW}Please install the missing tools and run this script again.${NC}"
    exit 1
fi

