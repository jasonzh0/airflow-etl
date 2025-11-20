# Deployment Guide - Dog Breeds System on Kubernetes

This guide provides step-by-step instructions for deploying the complete Dog Breeds system on Kubernetes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Deployment](#quick-deployment)
3. [Manual Deployment](#manual-deployment)
4. [Verification](#verification)
5. [Configuration](#configuration)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools

- **Docker** 20.10+ (for kind and image building)
- **kubectl** 1.28+ (Kubernetes CLI)
- **kind** 0.20+ (Kubernetes in Docker)
- **Helm** 3.10+ (Kubernetes package manager)
- **Node.js** 18+ (for dashboard)
- **psql** (PostgreSQL client, optional for testing)

### Verify Prerequisites

```bash
./scripts/check-prerequisites.sh
```

This script will check for all required tools and attempt to install missing ones on macOS.

## Quick Deployment

### One-Command Setup

```bash
# 1. Deploy Airflow
./scripts/start-airflow.sh

# 2. Deploy Dog Breeds system
./scripts/deploy-all.sh

# 3. Start dashboard
cd dashboard && npm install && npm run dev
```

### Access Points

- **Airflow UI**: http://localhost:8080 (admin/admin)
- **API Docs**: http://localhost:30800/docs
- **Dashboard**: http://localhost:5173
- **Database**: localhost:30432

## Manual Deployment

### Step 1: Create Kubernetes Cluster

```bash
./scripts/setup-kind-cluster.sh
```

This creates a kind cluster named `airflow-cluster` with:
- Port mappings for NodePort services
- Proper configuration for Airflow

Verify:
```bash
kubectl cluster-info
kind get clusters
```

### Step 2: Deploy Airflow

```bash
./scripts/deploy-airflow.sh
```

This:
- Adds Apache Airflow Helm repository
- Creates `airflow` namespace
- Installs Airflow with LocalExecutor
- Waits for all pods to be ready

Verify:
```bash
kubectl get pods -n airflow
kubectl get svc -n airflow
```

### Step 3: Setup Port Forwarding

```bash
./scripts/port-forward.sh
```

This forwards port 8080 to the Airflow webserver.

Access: http://localhost:8080 (admin/admin)

### Step 4: Deploy Dog Breeds Database

```bash
./scripts/deploy-dog-breeds-db.sh
```

This creates:
- `dog-breeds` namespace
- PostgreSQL deployment with schema
- PersistentVolumeClaim (5Gi)
- ClusterIP service (internal)
- NodePort service (external, port 30432)

Verify:
```bash
kubectl get all -n dog-breeds
kubectl logs -n dog-breeds -l component=database

# Test connection
psql -h localhost -p 30432 -U airflow -d dog_breeds_db -c "SELECT version();"
```

### Step 5: Configure Airflow Database Connection

```bash
./scripts/setup-airflow-db-connection.sh
```

This creates ConfigMap and Secret in the `airflow` namespace with database connection details.

The Helm values already include environment variable configuration, but you need to upgrade Airflow:

```bash
helm upgrade airflow apache-airflow/airflow -n airflow -f helm/values.yaml
```

Or restart pods:
```bash
kubectl rollout restart deployment -n airflow
```

Verify:
```bash
# Check environment variables
kubectl exec -n airflow -it deployment/airflow-scheduler -- env | grep DOG_BREEDS
```

### Step 6: Deploy API Backend

```bash
./scripts/deploy-dog-breeds-api.sh
```

This:
- Builds Docker image from `api/` directory
- Loads image into kind cluster
- Creates deployment with 2 replicas
- Creates services (ClusterIP and NodePort)
- Sets up health checks

Verify:
```bash
kubectl get pods -n dog-breeds -l component=api
kubectl logs -n dog-breeds -l component=api

# Test API
curl http://localhost:30800/health
curl http://localhost:30800/api/breeds/recent?limit=5
```

### Step 7: Trigger DAG

```bash
# Via Airflow UI
open http://localhost:8080
# Navigate to DAGs → dog_breed_fetcher → Trigger DAG

# Via CLI
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  airflow dags trigger dog_breed_fetcher
```

### Step 8: Start Dashboard

```bash
cd dashboard
npm install
npm run dev
```

Access: http://localhost:5173

## Verification

### System Health Check

```bash
./scripts/status.sh
```

### Component-by-Component Verification

#### 1. Kubernetes Cluster
```bash
kubectl cluster-info
kubectl get nodes
```

#### 2. Airflow
```bash
kubectl get pods -n airflow
kubectl get svc -n airflow
curl http://localhost:8080/health
```

#### 3. Database
```bash
kubectl get pods -n dog-breeds -l component=database
psql -h localhost -p 30432 -U airflow -d dog_breeds_db -c "\dt"
psql -h localhost -p 30432 -U airflow -d dog_breeds_db -c "SELECT COUNT(*) FROM dog_breeds;"
```

#### 4. API
```bash
kubectl get pods -n dog-breeds -l component=api
curl http://localhost:30800/health
curl http://localhost:30800/api/breeds/stats
```

#### 5. Dashboard
```bash
# Should be running on port 5173
curl http://localhost:5173
```

### End-to-End Test

```bash
# 1. Trigger DAG
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  airflow dags trigger dog_breed_fetcher

# 2. Wait for completion (check in UI or CLI)
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  airflow dags list-runs -d dog_breed_fetcher

# 3. Query database
psql -h localhost -p 30432 -U airflow -d dog_breeds_db -c \
  "SELECT breed_name, execution_date FROM dog_breeds ORDER BY execution_date DESC LIMIT 5;"

# 4. Test API
curl http://localhost:30800/api/breeds/recent?limit=5 | jq

# 5. Check dashboard
open http://localhost:5173
```

## Configuration

### Airflow Configuration

Edit `helm/values.yaml`:

```yaml
# Change executor
executor: "CeleryExecutor"  # or "KubernetesExecutor"

# Change resources
scheduler:
  resources:
    limits:
      cpu: 2000m
      memory: 4Gi

# Change DAG schedule
# Edit dags/dog_breed_dag.py
schedule=timedelta(minutes=30)  # Run every 30 minutes
```

Apply changes:
```bash
helm upgrade airflow apache-airflow/airflow -n airflow -f helm/values.yaml
```

### Database Configuration

Edit `k8s/dog-breeds-db/03-secret.yaml` to change password:

```yaml
stringData:
  POSTGRES_PASSWORD: "your-secure-password"
```

Edit `k8s/dog-breeds-db/04-pvc.yaml` to change storage size:

```yaml
resources:
  requests:
    storage: 10Gi  # Increase to 10GB
```

Apply changes:
```bash
kubectl apply -f k8s/dog-breeds-db/
```

### API Configuration

Edit `k8s/dog-breeds-api/01-configmap.yaml`:

```yaml
data:
  ALLOWED_ORIGINS: "http://localhost:5173,https://your-domain.com"
```

Edit `k8s/dog-breeds-api/02-deployment.yaml` to change replicas:

```yaml
spec:
  replicas: 4  # Increase to 4 replicas
```

Apply changes:
```bash
kubectl apply -f k8s/dog-breeds-api/
```

### Dashboard Configuration

Edit `dashboard/.env` (create if doesn't exist):

```env
VITE_DOG_BREEDS_API_URL=http://localhost:30800
```

Restart dev server:
```bash
cd dashboard
npm run dev
```

## Troubleshooting

### Quick Diagnostics

```bash
# Check all resources
kubectl get all -n airflow
kubectl get all -n dog-breeds

# Check logs
kubectl logs -n airflow -l component=scheduler --tail=100
kubectl logs -n dog-breeds -l component=database --tail=50
kubectl logs -n dog-breeds -l component=api --tail=50

# Check events
kubectl get events -n airflow --sort-by='.lastTimestamp'
kubectl get events -n dog-breeds --sort-by='.lastTimestamp'
```

### Common Issues

See main [README.md](README.md#troubleshooting) for detailed troubleshooting guide.

### Complete Reset

If you need to start fresh:

```bash
# Clean everything
./scripts/cleanup.sh

# Verify cleanup
kind get clusters
kubectl get namespaces

# Start over
./scripts/start-airflow.sh
./scripts/deploy-all.sh
```

## Production Considerations

For production deployments:

1. **Security**
   - Change all default passwords
   - Enable TLS/HTTPS
   - Use Kubernetes Secrets for sensitive data
   - Enable Pod Security Standards
   - Configure network policies

2. **High Availability**
   - Increase replicas for API (3+)
   - Use CeleryExecutor or KubernetesExecutor
   - Configure database replication
   - Use external PostgreSQL (managed service)

3. **Monitoring**
   - Enable Prometheus metrics
   - Configure Grafana dashboards
   - Set up alerting
   - Enable audit logging

4. **Backup & Recovery**
   - Configure automated database backups
   - Use persistent volumes with backups
   - Document recovery procedures

5. **Resource Management**
   - Set appropriate resource requests/limits
   - Configure horizontal pod autoscaling
   - Use node affinity/anti-affinity

6. **Storage**
   - Use production-grade storage class
   - Enable persistent storage for logs
   - Configure backup retention

## Next Steps

After deployment:

1. **Customize DAG**: Edit `dags/dog_breed_dag.py` for your use case
2. **Add more DAGs**: Place new DAG files in `dags/` directory
3. **Extend API**: Add endpoints in `api/main.py`
4. **Customize Dashboard**: Modify React components in `dashboard/src/`
5. **Configure Monitoring**: Set up Prometheus/Grafana
6. **Enable CI/CD**: Automate deployments with GitHub Actions or similar

## Support

- **Documentation**: See [README.md](README.md)
- **Scripts Reference**: See [scripts/README.md](scripts/README.md)
- **Airflow Docs**: https://airflow.apache.org/docs/
- **FastAPI Docs**: https://fastapi.tiangolo.com/
- **Kubernetes Docs**: https://kubernetes.io/docs/

