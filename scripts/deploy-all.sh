#!/bin/bash

# Deploy complete system to Kubernetes
# This script deploys Airflow, database, API, and configures connections

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=================================================="
echo "🚀 Complete System Deployment"
echo "==================================================${NC}"
echo ""
echo "This script will deploy:"
echo "  1. Apache Airflow"
echo "  2. PostgreSQL Database (Dog Breeds)"
echo "  3. FastAPI Backend"
echo "  4. Airflow Database Connection"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi

echo ""
echo "Starting deployment..."
echo ""

# ============================================
# Prerequisites Check
# ============================================
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl.${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm not found. Please install Helm.${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 is not installed.${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Please install Docker.${NC}"
    exit 1
fi

# Check if kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "airflow-cluster"; then
    echo -e "${RED}❌ Kind cluster 'airflow-cluster' not found.${NC}"
    echo "Please run ./scripts/setup-kind-cluster.sh first."
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo ""

# Install/upgrade Python dependencies if needed
cd "$PROJECT_DIR"
if [ -f "pyproject.toml" ]; then
    # Use uv if available, otherwise fall back to pip
    if command -v uv &> /dev/null; then
        if [ ! -d ".venv" ]; then
            echo -e "${BLUE}Creating virtual environment with uv...${NC}"
            uv venv
        fi
        echo -e "${BLUE}Installing dependencies with uv...${NC}"
        uv pip install kubeman pyyaml > /dev/null 2>&1
        PYTHON_CMD=".venv/bin/python"
    elif [ -f ".venv/bin/python" ]; then
        PYTHON_CMD=".venv/bin/python"
    elif python3 -c "import kubeman" 2>/dev/null; then
        PYTHON_CMD="python3"
    else
        echo -e "${YELLOW}Installing kubeman...${NC}"
        pip3 install -e . > /dev/null 2>&1 || {
            pip3 install --user -e . > /dev/null 2>&1
        }
        PYTHON_CMD="python3"
    fi
else
    PYTHON_CMD="python3"
fi

# Set kubectl context
kubectl config use-context kind-airflow-cluster

# ============================================
# Step 1: Deploy Airflow
# ============================================
echo -e "${BLUE}=================================================="
echo "Step 1: Deploying Apache Airflow"
echo "==================================================${NC}"
echo ""

RELEASE_NAME="airflow"
NAMESPACE="airflow"
HELM_REPO="apache-airflow"
HELM_REPO_URL="https://airflow.apache.org"

# Render templates with kubeman CLI
echo -e "${BLUE}Rendering templates with kubeman...${NC}"
"$PYTHON_CMD" -c "from kubeman import cli; import sys; sys.argv = ['kubeman', 'render', '--file', '$PROJECT_DIR/render.py']; cli.main()" || echo -e "${YELLOW}Warning: Template rendering failed, continuing with Helm deployment...${NC}"

# Copy manifests from venv to project root (kubeman writes to package location)
venv_manifests="$PROJECT_DIR/.venv/lib/python3.13/manifests"
project_manifests="$PROJECT_DIR/manifests"
if [ -d "$venv_manifests" ]; then
    if [ -d "$project_manifests" ]; then
        rm -rf "$project_manifests"
    fi
    cp -r "$venv_manifests" "$project_manifests"
    echo -e "${GREEN}Manifests copied to: $project_manifests${NC}"
fi
echo ""

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
    echo -e "${YELLOW}Will upgrade with --force flag to handle conflicts${NC}"
    ACTION="upgrade"
else
    ACTION="install"
fi

if [ "$SKIP_AIRFLOW" != "true" ]; then
    # Generate values from kubeman template
    echo -e "${BLUE}Generating Helm values from kubeman template...${NC}"
    VALUES_OUTPUT=$(cd "$PROJECT_DIR" && "$PYTHON_CMD" <<PYTHON_SCRIPT
import sys
sys.path.insert(0, '.')
from templates.airflow_chart import AirflowChart
import yaml
chart = AirflowChart()
values = chart.generate_values()
print(yaml.dump(values))
PYTHON_SCRIPT
)

    # Deploy Airflow
    if [ "$ACTION" == "install" ]; then
        echo -e "${BLUE}Installing Airflow...${NC}"
        echo "$VALUES_OUTPUT" | helm install "$RELEASE_NAME" "$HELM_REPO/airflow" \
            --namespace "$NAMESPACE" \
            --values - \
            --wait \
            --timeout 10m
    else
        echo -e "${BLUE}Upgrading Airflow...${NC}"
        # Delete conflicting secret if it exists to avoid upgrade conflicts
        kubectl delete secret airflow-api-secret-key -n "$NAMESPACE" --ignore-not-found=true 2>/dev/null || true
        # Perform upgrade
        echo "$VALUES_OUTPUT" | helm upgrade "$RELEASE_NAME" "$HELM_REPO/airflow" \
            --namespace "$NAMESPACE" \
            --values - \
            --wait \
            --timeout 10m
    fi

    echo ""
    echo -e "${BLUE}Waiting for Airflow pods to be ready...${NC}"
    kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=600s || {
        echo -e "${YELLOW}Some pods may still be starting. Check status with: kubectl get pods -n $NAMESPACE${NC}"
    }
    echo ""
fi

# ============================================
# Step 2: Deploy Database
# ============================================
echo -e "${BLUE}=================================================="
echo "Step 2: Deploying PostgreSQL Database"
echo "==================================================${NC}"
echo ""

MANIFESTS_DIR="$PROJECT_DIR/manifests/dog-breeds-db"

# Render templates with kubeman CLI
echo "Rendering templates with kubeman..."
"$PYTHON_CMD" -c "from kubeman import cli; import sys; sys.argv = ['kubeman', 'render', '--file', '$PROJECT_DIR/render.py']; cli.main()" || {
    echo -e "${RED}❌ Failed to render templates${NC}"
    exit 1
}

# Copy manifests from venv to project root
venv_manifests="$PROJECT_DIR/.venv/lib/python3.13/manifests"
project_manifests="$PROJECT_DIR/manifests"
if [ -d "$venv_manifests" ]; then
    if [ -d "$project_manifests" ]; then
        rm -rf "$project_manifests"
    fi
    cp -r "$venv_manifests" "$project_manifests"
fi

# Check if manifests directory exists
if [ ! -d "$MANIFESTS_DIR" ]; then
    echo -e "${RED}❌ Manifests directory not found: $MANIFESTS_DIR${NC}"
    echo "Make sure templates were rendered successfully"
    exit 1
fi

# Apply all manifests from the rendered directory
echo "Applying manifests from $MANIFESTS_DIR..."
kubectl apply -f "$MANIFESTS_DIR" --recursive || {
    # Fallback: apply individual files if recursive doesn't work
    for manifest in "$MANIFESTS_DIR"/*.yaml; do
        if [ -f "$manifest" ]; then
            kubectl apply -f "$manifest"
        fi
    done
}

echo ""
echo "Waiting for database to be ready..."
kubectl wait --for=condition=ready pod -l app=dog-breeds,component=database -n dog-breeds --timeout=300s

echo ""
echo -e "${GREEN}✅ Database deployed successfully!${NC}"
echo ""

# ============================================
# Step 3: Deploy API
# ============================================
echo -e "${BLUE}=================================================="
echo "Step 3: Deploying FastAPI Backend"
echo "==================================================${NC}"
echo ""

API_DIR="$PROJECT_DIR/api"
MANIFESTS_DIR="$PROJECT_DIR/manifests/dog-breeds-api"

echo "Building Docker image..."
cd "$API_DIR"
docker build -t dog-breeds-api:latest .

echo ""
echo "Loading image into kind cluster..."
kind load docker-image dog-breeds-api:latest --name airflow-cluster

echo ""
echo "Deploying Dog Breeds API..."

# Check if manifests directory exists
if [ ! -d "$MANIFESTS_DIR" ]; then
    echo -e "${RED}❌ Manifests directory not found: $MANIFESTS_DIR${NC}"
    echo "Make sure templates were rendered successfully"
    exit 1
fi

# Apply all manifests from the rendered directory
echo "Applying manifests from $MANIFESTS_DIR..."
kubectl apply -f "$MANIFESTS_DIR" --recursive || {
    # Fallback: apply individual files if recursive doesn't work
    for manifest in "$MANIFESTS_DIR"/*.yaml; do
        if [ -f "$manifest" ]; then
            kubectl apply -f "$manifest" || true  # Ingress might fail if NGINX not installed
        fi
    done
}

echo ""
echo "Note: Ingress creation may fail if NGINX Ingress Controller is not installed (this is optional)"
echo ""
echo "Waiting for API to be ready..."
kubectl wait --for=condition=ready pod -l app=dog-breeds,component=api -n dog-breeds --timeout=300s

echo ""
echo -e "${GREEN}✅ API deployed successfully!${NC}"
echo ""

# ============================================
# Step 4: Configure Airflow Connection
# ============================================
echo -e "${BLUE}=================================================="
echo "Step 4: Configuring Airflow Database Connection"
echo "==================================================${NC}"
echo ""

# Check if dog-breeds namespace exists
if ! kubectl get namespace dog-breeds &> /dev/null; then
    echo -e "${RED}❌ dog-breeds namespace not found.${NC}"
    exit 1
fi

# Check if Airflow is deployed
if ! kubectl get namespace airflow &> /dev/null; then
    echo -e "${RED}❌ Airflow namespace not found.${NC}"
    exit 1
fi

echo "Creating ConfigMap with database connection info in Airflow namespace..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: dog-breeds-db-connection
  namespace: airflow
  labels:
    app: airflow
data:
  DOG_BREEDS_DB_HOST: "dog-breeds-db.dog-breeds.svc.cluster.local"
  DOG_BREEDS_DB_PORT: "5432"
  DOG_BREEDS_DB_NAME: "dog_breeds_db"
  DOG_BREEDS_DB_USER: "airflow"
EOF

echo ""
echo "Creating Secret with database password in Airflow namespace..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: dog-breeds-db-connection
  namespace: airflow
  labels:
    app: airflow
type: Opaque
stringData:
  DOG_BREEDS_DB_PASSWORD: "airflow"
EOF

echo ""
echo -e "${GREEN}✅ Airflow connection configured!${NC}"
echo ""

# ============================================
# Summary
# ============================================
echo -e "${GREEN}=================================================="
echo "✅ Complete Deployment Finished!"
echo "==================================================${NC}"
echo ""
echo "System Overview:"
echo "  📦 Database: localhost:30432"
echo "  🔌 API: http://localhost:30800"
echo "  ✈️  Airflow: http://localhost:8080"
echo ""
echo "Quick Tests:"
echo "  # Test API health"
echo "  curl http://localhost:30800/health"
echo ""
echo "  # View API docs"
echo "  open http://localhost:30800/docs"
echo ""
echo "  # Check database"
echo "  psql -h localhost -p 30432 -U airflow -d dog_breeds_db"
echo ""
echo "Access Information:"
echo "  Airflow UI: http://localhost:8080 (admin/admin)"
echo "  API Docs: http://localhost:30800/docs"
echo "  Database: localhost:30432"
echo ""
echo "Next Steps:"
echo "  1. Set up port forwarding: ./scripts/port-forward.sh"
echo "  2. Trigger the dog_breed_fetcher DAG in Airflow UI"
echo "  3. Start the dashboard: cd dashboard && npm run dev"
echo ""
