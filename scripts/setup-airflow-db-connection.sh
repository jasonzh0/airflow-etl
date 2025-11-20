#!/bin/bash

# Configure Airflow to connect to the Dog Breeds Database
# This script adds environment variables to Airflow pods for database connectivity

set -e  # Exit on error

echo "=================================================="
echo "Configure Airflow Database Connection"
echo "=================================================="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl."
    exit 1
fi

# Check if kind cluster exists
if ! kind get clusters 2>/dev/null | grep -q "airflow-cluster"; then
    echo "❌ Kind cluster 'airflow-cluster' not found."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Set kubectl context
kubectl config use-context kind-airflow-cluster

# Check if dog-breeds namespace exists
if ! kubectl get namespace dog-breeds &> /dev/null; then
    echo "❌ dog-breeds namespace not found."
    echo "Please run ./scripts/deploy-dog-breeds-db.sh first."
    exit 1
fi

# Check if Airflow is deployed
if ! kubectl get namespace airflow &> /dev/null; then
    echo "❌ Airflow namespace not found."
    echo "Please deploy Airflow first using ./scripts/deploy-airflow.sh"
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
echo "=================================================="
echo "✅ Configuration Created!"
echo "=================================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Update your Airflow Helm values to include these environment variables:"
echo "   Add to helm/values.yaml under 'env' section:"
echo ""
echo "   env:"
echo "     - name: DOG_BREEDS_DB_HOST"
echo "       valueFrom:"
echo "         configMapKeyRef:"
echo "           name: dog-breeds-db-connection"
echo "           key: DOG_BREEDS_DB_HOST"
echo "     - name: DOG_BREEDS_DB_PORT"
echo "       valueFrom:"
echo "         configMapKeyRef:"
echo "           name: dog-breeds-db-connection"
echo "           key: DOG_BREEDS_DB_PORT"
echo "     - name: DOG_BREEDS_DB_NAME"
echo "       valueFrom:"
echo "         configMapKeyRef:"
echo "           name: dog-breeds-db-connection"
echo "           key: DOG_BREEDS_DB_NAME"
echo "     - name: DOG_BREEDS_DB_USER"
echo "       valueFrom:"
echo "         configMapKeyRef:"
echo "           name: dog-breeds-db-connection"
echo "           key: DOG_BREEDS_DB_USER"
echo "     - name: DOG_BREEDS_DB_PASSWORD"
echo "       valueFrom:"
echo "         secretKeyRef:"
echo "           name: dog-breeds-db-connection"
echo "           key: DOG_BREEDS_DB_PASSWORD"
echo ""
echo "2. Also add psycopg2-binary to requirements.txt in Airflow"
echo ""
echo "3. Upgrade the Airflow Helm release:"
echo "   helm upgrade airflow apache-airflow/airflow -n airflow -f helm/values.yaml"
echo ""
echo "Or restart Airflow pods to pick up the new environment variables:"
echo "   kubectl rollout restart deployment -n airflow"
echo ""

