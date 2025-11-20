#!/bin/bash

# Deploy complete Dog Breeds system to Kubernetes
# This script deploys database, API, and configures Airflow

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================="
echo "🚀 Dog Breeds Complete Deployment"
echo "=================================================="
echo ""
echo "This script will deploy:"
echo "  1. PostgreSQL Database"
echo "  2. FastAPI Backend"
echo "  3. Configure Airflow connection"
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

# Deploy database
echo "=================================================="
echo "Step 1: Deploying Database"
echo "=================================================="
"$SCRIPT_DIR/deploy-dog-breeds-db.sh"

echo ""
sleep 5

# Deploy API
echo "=================================================="
echo "Step 2: Deploying API"
echo "=================================================="
"$SCRIPT_DIR/deploy-dog-breeds-api.sh"

echo ""
sleep 5

# Configure Airflow
echo "=================================================="
echo "Step 3: Configuring Airflow Connection"
echo "=================================================="
"$SCRIPT_DIR/setup-airflow-db-connection.sh"

echo ""
echo "=================================================="
echo "✅ Complete Deployment Finished!"
echo "=================================================="
echo ""
echo "System Overview:"
echo "  📦 Database: http://localhost:30432"
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
echo "Next Steps:"
echo "  1. Update Airflow Helm values (see configuration instructions above)"
echo "  2. Upgrade Airflow: helm upgrade airflow apache-airflow/airflow -n airflow -f helm/values.yaml"
echo "  3. Trigger the dog_breed_fetcher DAG in Airflow UI"
echo "  4. Start the dashboard: cd dashboard && npm run dev"
echo ""

