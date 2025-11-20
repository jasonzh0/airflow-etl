#!/bin/bash
# Port forward to Airflow webserver and Dog Breeds API
# This script sets up port forwarding to access services locally

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

AIRFLOW_NAMESPACE="airflow"
DOG_BREEDS_NAMESPACE="dog-breeds"
RELEASE_NAME="airflow"
AIRFLOW_LOCAL_PORT=8080
API_LOCAL_PORT=30800

echo -e "${BLUE}Setting up port forwarding for Airflow and Dog Breeds API...${NC}"
echo ""

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Error: kubectl is not configured or cluster is not accessible${NC}"
    exit 1
fi

# Function to check and kill process on port
check_and_kill_port() {
    local port=$1
    local service_name=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${YELLOW}Port $port is already in use${NC}"
        read -p "Kill existing process and continue? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            lsof -ti:$port | xargs kill -9 2>/dev/null || true
            sleep 1
        else
            echo "Skipping $service_name port forwarding"
            return 1
        fi
    fi
    return 0
}

# Check Airflow namespace
if ! kubectl get namespace "$AIRFLOW_NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Warning: Namespace '$AIRFLOW_NAMESPACE' does not exist${NC}"
    echo "Airflow may not be deployed. Skipping Airflow port forward."
    AIRFLOW_AVAILABLE=false
else
    AIRFLOW_AVAILABLE=true
fi

# Check Dog Breeds namespace
if ! kubectl get namespace "$DOG_BREEDS_NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}Warning: Namespace '$DOG_BREEDS_NAMESPACE' does not exist${NC}"
    echo "Dog Breeds system may not be deployed. Skipping API port forward."
    API_AVAILABLE=false
else
    API_AVAILABLE=true
fi

# Check Airflow service
if [ "$AIRFLOW_AVAILABLE" = true ]; then
    API_SERVICE="${RELEASE_NAME}-api-server"
    if ! kubectl get svc "$API_SERVICE" -n "$AIRFLOW_NAMESPACE" &> /dev/null; then
        echo -e "${YELLOW}Warning: Service '$API_SERVICE' not found${NC}"
        AIRFLOW_AVAILABLE=false
    fi
fi

# Check Dog Breeds API service
if [ "$API_AVAILABLE" = true ]; then
    if ! kubectl get svc "dog-breeds-api" -n "$DOG_BREEDS_NAMESPACE" &> /dev/null; then
        echo -e "${YELLOW}Warning: Service 'dog-breeds-api' not found${NC}"
        API_AVAILABLE=false
    fi
fi

# Check ports
if [ "$AIRFLOW_AVAILABLE" = true ]; then
    if ! check_and_kill_port $AIRFLOW_LOCAL_PORT "Airflow"; then
        AIRFLOW_AVAILABLE=false
    fi
fi

if [ "$API_AVAILABLE" = true ]; then
    if ! check_and_kill_port $API_LOCAL_PORT "Dog Breeds API"; then
        API_AVAILABLE=false
    fi
fi

# Exit if nothing to forward
if [ "$AIRFLOW_AVAILABLE" = false ] && [ "$API_AVAILABLE" = false ]; then
    echo -e "${RED}Error: No services available to port forward${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Starting port forwarding...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop all port forwarding${NC}"
echo ""

# Build port forward commands
PORTS=()
NAMESPACES=()
SERVICES=()
PORTS_MAP=()

if [ "$AIRFLOW_AVAILABLE" = true ]; then
    echo -e "${GREEN}✓ Airflow UI: http://localhost:$AIRFLOW_LOCAL_PORT${NC}"
    PORTS+=($AIRFLOW_LOCAL_PORT)
    NAMESPACES+=($AIRFLOW_NAMESPACE)
    SERVICES+=("$API_SERVICE")
    PORTS_MAP+=("$AIRFLOW_LOCAL_PORT:8080")
fi

if [ "$API_AVAILABLE" = true ]; then
    echo -e "${GREEN}✓ Dog Breeds API: http://localhost:$API_LOCAL_PORT${NC}"
    echo -e "${GREEN}  API Docs: http://localhost:$API_LOCAL_PORT/docs${NC}"
    PORTS+=($API_LOCAL_PORT)
    NAMESPACES+=($DOG_BREEDS_NAMESPACE)
    SERVICES+=("dog-breeds-api")
    PORTS_MAP+=("$API_LOCAL_PORT:8000")
fi

echo ""

# Start port forwarding in background for each service
PIDS=()

for i in "${!PORTS[@]}"; do
    port="${PORTS[$i]}"
    namespace="${NAMESPACES[$i]}"
    service="${SERVICES[$i]}"
    port_map="${PORTS_MAP[$i]}"
    
    echo -e "${BLUE}Forwarding port $port_map for $service...${NC}"
    
    kubectl port-forward \
        -n "$namespace" \
        svc/"$service" \
        $port_map \
        > /dev/null 2>&1 &
    
    PIDS+=($!)
    sleep 1
done

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping port forwarding...${NC}"
    for pid in "${PIDS[@]}"; do
        kill $pid 2>/dev/null || true
    done
    echo -e "${GREEN}Port forwarding stopped${NC}"
    exit 0
}

# Trap SIGINT and SIGTERM
trap cleanup SIGINT SIGTERM

# Wait for all background processes
echo -e "${GREEN}Port forwarding active. Press Ctrl+C to stop.${NC}"
echo ""

# Wait for all background jobs
wait

