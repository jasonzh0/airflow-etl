# Airflow 3 Kubernetes Setup

This project sets up Apache Airflow 3.x on a local Kubernetes cluster using [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker) and the official [Apache Airflow Helm chart](https://airflow.apache.org/docs/helm-chart/stable/index.html).

## Prerequisites

Before getting started, ensure you have the following tools installed:

- **Docker** - For running kind and containers
  - Install: [Docker Desktop](https://docs.docker.com/get-docker/) or Docker Engine
- **kubectl** - Kubernetes command-line tool
  - Install: [kubectl installation guide](https://kubernetes.io/docs/tasks/tools/)
- **kind** - Kubernetes in Docker
  - Install: `brew install kind` (macOS) or [kind installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- **Helm 3.10+** - Kubernetes package manager
  - Install: `brew install helm` (macOS) or [Helm installation guide](https://helm.sh/docs/intro/install/)

## Quick Start

### 1. Check Prerequisites

Run the prerequisites check script to verify all required tools are installed:

```bash
./scripts/check-prerequisites.sh
```

This script will:
- Verify Docker, kubectl, kind, and Helm are installed
- Check if Docker daemon is running
- Attempt to install missing tools (where possible)

### 2. Start Airflow

The easiest way to get started is to use the all-in-one start script:

```bash
./scripts/start-airflow.sh
```

This script will:
1. Check prerequisites
2. Create a kind cluster named `airflow-cluster`
3. Deploy Airflow using Helm
4. Set up port forwarding to access the UI

### 3. Access Airflow UI

Once the deployment is complete, access the Airflow UI at:

**http://localhost:8080**

**Default credentials:**
- Username: `admin`
- Password: `admin`

> **Note:** You can change the default credentials in `helm/values.yaml` before deployment.

## Scripts Overview

The project includes several helper scripts in the `scripts/` directory:

### Setup Scripts

- **`check-prerequisites.sh`** - Verify all required tools are installed
- **`setup-kind-cluster.sh`** - Create and configure the kind cluster
- **`deploy-airflow.sh`** - Deploy Airflow to Kubernetes using Helm

### Management Scripts

- **`start-airflow.sh`** - Complete setup: cluster + deployment + port forwarding
- **`stop-airflow.sh`** - Stop Airflow (with options to keep/delete deployment)
- **`port-forward.sh`** - Set up port forwarding to access Airflow UI
- **`status.sh`** - Check the status of cluster and Airflow deployment
- **`cleanup.sh`** - Complete cleanup (removes everything)

## Manual Setup Steps

If you prefer to run steps manually:

### 1. Check Prerequisites

```bash
./scripts/check-prerequisites.sh
```

### 2. Create Kind Cluster

```bash
./scripts/setup-kind-cluster.sh
```

### 3. Deploy Airflow

```bash
./scripts/deploy-airflow.sh
```

### 4. Set Up Port Forwarding

```bash
./scripts/port-forward.sh
```

## Configuration

### Helm Values

Airflow configuration is managed through `helm/values.yaml`. Key settings include:

- **Airflow Version**: 3.0.0 (configurable)
- **Executor**: LocalExecutor (can be changed to CeleryExecutor or KubernetesExecutor)
- **Database**: PostgreSQL (managed by Helm chart)
- **Resources**: Configured for local development

To customize Airflow settings, edit `helm/values.yaml` before deployment.

### Changing Executor

To use a different executor, modify `helm/values.yaml`:

```yaml
executor: "CeleryExecutor"  # or "KubernetesExecutor"
```

For CeleryExecutor, also enable Redis:

```yaml
redis:
  enabled: true
```

### Changing Default Credentials

Edit `helm/values.yaml`:

```yaml
users:
  - username: your_username
    password: your_password
    role: Admin
```

## Adding DAGs

Place your Airflow DAG files in the `dags/` directory. The Helm chart will automatically mount this directory into the Airflow pods.

### Option 1: Local DAGs Directory (Current Setup)

DAGs in the `dags/` directory are mounted via persistent volume. Simply add your DAG files:

```bash
# Add your DAG file
cp my_dag.py dags/
```

### Option 2: Git Sync (Advanced)

To use Git sync for DAGs, enable it in `helm/values.yaml`:

```yaml
dags:
  gitSync:
    enabled: true
    repo: https://github.com/your-org/your-dags-repo
    branch: main
    subPath: "dags"
```

## Useful Commands

### Check Status

```bash
./scripts/status.sh
```

### View Pods

```bash
kubectl get pods -n airflow
```

### View Logs

```bash
# Scheduler logs
kubectl logs -n airflow -l component=scheduler --tail=100

# Webserver logs
kubectl logs -n airflow -l component=webserver --tail=100

# Specific pod logs
kubectl logs -n airflow <pod-name>
```

### Access Airflow CLI

```bash
# Execute commands in the scheduler pod
kubectl exec -n airflow -it deployment/airflow-scheduler -- airflow <command>

# Example: List DAGs
kubectl exec -n airflow -it deployment/airflow-scheduler -- airflow dags list
```

### Port Forwarding

If port forwarding stops, restart it:

```bash
./scripts/port-forward.sh
```

To stop port forwarding:

```bash
pkill -f 'kubectl.*port-forward.*airflow'
```

## Stopping Airflow

### Stop Port Forwarding Only

```bash
pkill -f 'kubectl.*port-forward.*airflow'
```

### Stop with Options

```bash
./scripts/stop-airflow.sh
```

This will prompt you to:
1. Keep deployment (just stop port forwarding)
2. Delete Airflow deployment (keep cluster)
3. Delete everything (Airflow + cluster)

## Complete Cleanup

To remove everything (Helm release, namespace, and kind cluster):

```bash
./scripts/cleanup.sh
```

**Warning:** This will delete all data and cannot be undone.

## Troubleshooting

### Port 8080 Already in Use

If port 8080 is already in use:

```bash
# Find the process using the port
lsof -i :8080

# Kill the process (replace PID with actual process ID)
kill -9 <PID>
```

Or change the port in `scripts/port-forward.sh`:

```bash
LOCAL_PORT=8081  # Change this
```

### Pods Not Starting

Check pod status and events:

```bash
kubectl get pods -n airflow
kubectl describe pod <pod-name> -n airflow
kubectl get events -n airflow --sort-by='.lastTimestamp'
```

### Database Migration Issues

If database migrations fail, you can manually run them:

```bash
kubectl exec -n airflow -it deployment/airflow-scheduler -- airflow db upgrade
```

### Kind Cluster Issues

If the kind cluster has issues, delete and recreate:

```bash
kind delete cluster --name airflow-cluster
./scripts/setup-kind-cluster.sh
```

### Helm Chart Issues

Update Helm repositories:

```bash
helm repo update apache-airflow
```

## Architecture

### Components

- **Webserver**: Airflow UI and API (port 8080)
- **Scheduler**: Schedules and triggers tasks
- **Triggerer**: Handles deferred tasks (e.g., sensors)
- **DAG Processor**: Processes DAG files
- **PostgreSQL**: Metadata database
- **Redis**: Message broker (only for CeleryExecutor)

### Resources

Default resource limits (suitable for local development):
- Webserver: 1 CPU, 2Gi memory
- Scheduler: 1 CPU, 2Gi memory
- Triggerer: 500m CPU, 1Gi memory
- DAG Processor: 500m CPU, 1Gi memory

Adjust in `helm/values.yaml` if needed.

## References

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Airflow Helm Chart Documentation](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [kind Documentation](https://kind.sigs.k8s.io/)
- [Helm Documentation](https://helm.sh/docs/)

## License

This setup uses Apache Airflow, which is licensed under the Apache License 2.0.
