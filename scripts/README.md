# Scripts Directory

This directory contains deployment and management scripts for the Airflow + Dog Breeds system.

## Quick Start Scripts

### Initial Setup
```bash
# 1. Check prerequisites (Docker, kubectl, kind, Helm)
./check-prerequisites.sh

# 2. Create kind cluster
./setup-kind-cluster.sh

# 3. Deploy Airflow
./deploy-airflow.sh

# 4. Deploy Dog Breeds system (Database + API)
./deploy-all.sh

# 5. Start port forwarding
./port-forward.sh
```

### One Command Setup (Airflow Only)
```bash
./start-airflow.sh
```

## Dog Breeds System Scripts

### Database Scripts
- **`deploy-dog-breeds-db.sh`** - Deploy PostgreSQL database to Kubernetes
  - Creates namespace, ConfigMaps, Secrets, PVC, Deployment, Service
  - Database accessible at: `localhost:30432` (NodePort)
  - Service: `dog-breeds-db.dog-breeds.svc.cluster.local:5432`

### API Scripts
- **`deploy-dog-breeds-api.sh`** - Build and deploy FastAPI backend
  - Builds Docker image
  - Loads image into kind cluster
  - Deploys API with 2 replicas
  - API accessible at: `http://localhost:30800` (NodePort)
  - Service: `dog-breeds-api.dog-breeds.svc.cluster.local:8000`

### Configuration Scripts
- **`setup-airflow-db-connection.sh`** - Configure Airflow to connect to Dog Breeds DB
  - Creates ConfigMap and Secret in Airflow namespace
  - Provides instructions for updating Helm values

### Complete Deployment
- **`deploy-all.sh`** - Deploy entire Dog Breeds system
  - Deploys database
  - Deploys API
  - Configures Airflow connection
  - One command to deploy everything

## Airflow Management Scripts

### Setup Scripts
- **`check-prerequisites.sh`** - Verify required tools are installed
  - Checks: Docker, kubectl, kind, Helm
  - Attempts to install missing tools (macOS)
  - Verifies Docker daemon is running

- **`setup-kind-cluster.sh`** - Create kind cluster for Airflow
  - Cluster name: `airflow-cluster`
  - Configures port mappings for NodePort services
  - Sets up proper cluster configuration

- **`deploy-airflow.sh`** - Deploy Airflow using Helm
  - Adds Apache Airflow Helm repository
  - Creates Airflow namespace
  - Installs/upgrades Airflow release
  - Waits for all pods to be ready

### Management Scripts
- **`start-airflow.sh`** - Complete setup: cluster + deployment + port-forward
  - Runs all setup steps in sequence
  - One command to get Airflow running

- **`stop-airflow.sh`** - Stop Airflow with options
  - Option 1: Keep deployment (stop port forwarding only)
  - Option 2: Delete Airflow deployment (keep cluster)
  - Option 3: Delete everything (Airflow + cluster)

- **`port-forward.sh`** - Set up port forwarding for Airflow UI
  - Forwards port 8080 to Airflow webserver
  - Runs in background
  - Access UI at: `http://localhost:8080`

- **`status.sh`** - Check status of cluster and deployments
  - Shows cluster status
  - Lists all pods in airflow namespace
  - Shows Dog Breeds namespace status
  - Displays access URLs

- **`cleanup.sh`** - Complete cleanup
  - Deletes Helm release
  - Deletes namespaces
  - Deletes kind cluster
  - **WARNING:** Removes all data

### Helm Template Generation
- **`generate-helm-templates.sh`** - Generate K8s templates from Helm chart
  - Generates YAML templates to `k8s/airflow/` directory
  - Useful for reviewing templates before deployment
  - Can apply templates manually with kubectl

## Script Categories

### 1. Prerequisites & Setup
```
check-prerequisites.sh    → Verify tools
setup-kind-cluster.sh     → Create cluster
```

### 2. Airflow Deployment
```
deploy-airflow.sh         → Deploy Airflow
start-airflow.sh          → All-in-one setup
```

### 3. Dog Breeds System
```
deploy-dog-breeds-db.sh   → Deploy database
deploy-dog-breeds-api.sh  → Deploy API
setup-airflow-db-connection.sh → Configure Airflow
deploy-all.sh             → Deploy everything
```

### 4. Management
```
port-forward.sh           → Port forwarding
status.sh                 → Check status
stop-airflow.sh           → Stop services
cleanup.sh                → Remove everything
```

### 5. Utilities
```
generate-helm-templates.sh → Generate YAML templates
```

## Common Workflows

### First Time Setup
```bash
# 1. Check and install prerequisites
./check-prerequisites.sh

# 2. Deploy Airflow
./start-airflow.sh

# 3. Deploy Dog Breeds system
./deploy-all.sh

# 4. Access the system
# Airflow UI: http://localhost:8080 (admin/admin)
# API Docs: http://localhost:30800/docs
# Database: localhost:30432
```

### Daily Development
```bash
# Check status
./status.sh

# If port forwarding stopped
./port-forward.sh

# View logs
kubectl logs -n airflow -l component=scheduler --tail=50
kubectl logs -n dog-breeds -l component=api --tail=50
```

### Restart API After Code Changes
```bash
# Rebuild and redeploy API
./deploy-dog-breeds-api.sh
```

### Update Airflow Configuration
```bash
# Edit helm/values.yaml
# Then upgrade Airflow
helm upgrade airflow apache-airflow/airflow -n airflow -f helm/values.yaml

# Or use the deploy script
./deploy-airflow.sh
```

### Complete Teardown
```bash
# Remove everything
./cleanup.sh

# Or stop with options
./stop-airflow.sh
```

## Troubleshooting

### Port Already in Use
```bash
# Find process using port 8080
lsof -i :8080

# Kill process
kill -9 <PID>

# Or change port in port-forward.sh
```

### Pods Not Starting
```bash
# Check pod status
kubectl get pods -n airflow
kubectl describe pod <pod-name> -n airflow

# Check events
kubectl get events -n airflow --sort-by='.lastTimestamp'

# View logs
kubectl logs -n airflow <pod-name>
```

### Database Connection Issues
```bash
# Check database pod
kubectl get pods -n dog-breeds
kubectl logs -n dog-breeds -l component=database

# Test connection from Airflow pod
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  bash -c "psql -h dog-breeds-db.dog-breeds.svc.cluster.local -U airflow -d dog_breeds_db"
```

### API Not Accessible
```bash
# Check API pods
kubectl get pods -n dog-breeds -l component=api
kubectl logs -n dog-breeds -l component=api

# Test health endpoint
curl http://localhost:30800/health

# Check service
kubectl get svc -n dog-breeds
```

## Environment Variables

### Scripts use these defaults:
- **Cluster name**: `airflow-cluster`
- **Airflow namespace**: `airflow`
- **Dog Breeds namespace**: `dog-breeds`
- **Airflow port**: `8080`
- **API port**: `30800` (NodePort)
- **Database port**: `30432` (NodePort)

## Notes

- All scripts are designed to be idempotent (can be run multiple times safely)
- Scripts check prerequisites before running
- Most scripts provide helpful output and next steps
- Port forwarding runs in background (check with `ps aux | grep port-forward`)
- Kind cluster uses local Docker for storage (data persists across pod restarts)
- Secrets use default passwords (change for production!)

## Production Considerations

For production deployments:
1. Change all default passwords in ConfigMaps and Secrets
2. Enable TLS/HTTPS
3. Configure proper resource limits
4. Enable persistent storage for logs
5. Set up proper monitoring and alerting
6. Use external database instead of embedded PostgreSQL
7. Configure proper backup strategy
8. Review and harden security settings

