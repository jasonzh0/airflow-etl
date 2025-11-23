# Airflow 3.1.3 Kubernetes Setup with Dog Breeds System

![Airflow UI Overview](./docs/airflow.png)

![Dog Breeds Dashboard](./docs/dashboard.png)

This project sets up **Apache Airflow 3.1.3** on a local Kubernetes cluster using [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker) and the official [Apache Airflow Helm chart](https://airflow.apache.org/docs/helm-chart/stable/index.html).

> **Note:** This project uses Airflow 3.1.3, which includes fixes for the Security/Users page bug present in 3.0.0.

It includes a complete **Dog Breeds System** that demonstrates:
- ✅ Airflow DAG fetching data from external API
- ✅ Storing data in external PostgreSQL database (in Kubernetes)
- ✅ **Airflow Assets connected to database records** for data lineage
- ✅ FastAPI backend serving data from database
- ✅ React dashboard consuming the API
- ✅ Complete Kubernetes deployment with proper service communication

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
- **Python 3.10+** - For kubeman template management
  - Install: [Python downloads](https://www.python.org/downloads/)
- **uv** - Fast Python package installer
  - Install: `pip install uv` or `brew install uv` (macOS)

## Quick Start

### Complete System Deployment

Deploy the entire system (Airflow + Dog Breeds Database + API) with a single command:

```bash
# 1. Check prerequisites
./scripts/check-prerequisites.sh

# 2. Setup kind cluster
./scripts/setup-kind-cluster.sh

# 3. Deploy everything
./scripts/deploy-all.sh

# 4. Start Dashboard
cd dashboard
npm install
npm run dev
```

> **Note:** The deployment script uses `kubeman` for Kubernetes template management and handles database migrations automatically.

**Access Points:**
- **Airflow UI**: http://localhost:8080 (admin/admin)
- **Dog Breeds API**: http://localhost:30800
- **API Docs**: http://localhost:30800/docs
- **Dashboard**: http://localhost:5173
- **Database**: localhost:30432

**Default Airflow credentials:**
- Username: `admin`
- Password: `admin`

**Deployment Time:** Initial deployment takes 5-10 minutes as it:
- Creates kind cluster
- Pulls container images
- Deploys PostgreSQL databases
- Runs Airflow database migrations
- Builds and loads custom API image
- Waits for all pods to be ready

## Project Structure

```
airflow/
├── dags/                       # Airflow DAG files
│   └── dog_breed_dag.py       # Dog breed fetcher DAG (stores in DB)
├── dashboard/                  # React dashboard
│   └── src/
│       ├── api.ts             # API client (connects to FastAPI)
│       └── components/        # React components
├── api/                       # FastAPI backend
│   ├── main.py               # FastAPI application
│   ├── Dockerfile            # API container image
│   └── requirements.txt      # Python dependencies
├── templates/                  # Kubernetes templates (kubeman)
│   ├── airflow_chart.py      # Airflow Helm chart definition
│   ├── dog_breeds_db_chart.py    # Database resources
│   └── dog_breeds_api_chart.py   # API resources
├── manifests/                  # Generated Kubernetes manifests
│   ├── airflow/              # Generated Airflow manifests
│   ├── dog-breeds-db/        # Generated database manifests
│   └── dog-breeds-api/       # Generated API manifests
├── scripts/                   # Deployment scripts
│   ├── deploy-all.sh         # Deploy complete system (main script)
│   └── ...                   # Other utility scripts
├── database/                  # Database schema
│   └── schema.sql            # PostgreSQL schema
├── pyproject.toml             # Python dependencies (kubeman)
└── render.py                  # Template registration for kubeman CLI
```

## System Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                      │
│                                                              │
│  ┌─────────────────┐                                         │
│  │ Airflow NS      │                                         │
│  │  ┌───────────┐  │                                         │
│  │  │ Scheduler │  │                                         │
│  │  │ API Server│  │───┐                                     │
│  │  │ DAG Files │  │   │                                     │
│  │  └───────────┘  │   │                                     │
│  └─────────────────┘   │                                     │
│                        │                                     │
│  ┌─────────────────────▼─────────────────┐                   │
│  │    Dog Breeds Namespace               │                   │
│  │  ┌──────────────┐   ┌──────────────┐  │                   │
│  │  │  PostgreSQL  │◄──│  FastAPI     │  │                   │
│  │  │   Database   │   │   Backend    │  │                   │
│  │  │              │   │              │  │                   │
│  │  │ Port: 5432   │   │ Port: 8000   │  │                   │
│  │  └──────────────┘   └──────────────┘  │                   │ 
│  │        │                   │          │                   │
│  └────────┼───────────────────┼──────────┘                   │
│           │                   │                              │
│    NodePort: 30432     NodePort: 30800                       │
└───────────┼───────────────────┼──────────────────────────────┘
            │                   │
            │                   │
   ┌────────▼───────┐  ┌────────▼─────────┐
   │   Database     │  │  React Dashboard │
   │   Client       │  │  (Vite + React)  │
   │   (psql)       │  │                  │
   └────────────────┘  │  Port: 5173      │
                       └──────────────────┘
```

### Data Flow

1. **Airflow DAG** fetches dog breed from Dog API every hour
2. **DAG** stores breed data in **PostgreSQL** (Kubernetes) with asset URI
3. **Airflow Asset** is created and linked to database record via `asset_uri` column
4. **FastAPI** backend queries database and serves REST API
5. **React Dashboard** displays breeds via API calls
6. **Database** accessible for direct queries and debugging
7. **Asset Lineage** tracks data from Airflow assets to database records

## Deployment Architecture

This project uses **kubeman v0.3.0** for Kubernetes template management, providing:
- Python-based template definitions (easier than YAML)
- Automatic manifest generation
- Helm chart integration
- Consistent deployment patterns

### Main Deployment Script

**`scripts/deploy-all.sh`** - Comprehensive deployment script that:
1. Checks prerequisites (kubectl, helm, docker, uv, kind cluster)
2. Sets up Python virtual environment with kubeman
3. Renders Kubernetes manifests from templates
4. Deploys Airflow via Helm with PostgreSQL
5. Runs Airflow database migrations
6. Deploys Dog Breeds PostgreSQL database
7. Builds and deploys FastAPI backend
8. Configures Airflow database connections

### Utility Scripts
- **`check-prerequisites.sh`** - Verify required tools
- **`setup-kind-cluster.sh`** - Create kind cluster with proper configuration
- **`port-forward.sh`** - Set up port forwarding for Airflow UI
- **`status.sh`** - Check system status
- **`cleanup.sh`** - Remove everything (complete teardown)

For detailed documentation, see [`scripts/README.md`](scripts/README.md).

## Kubeman Template Management

This project uses **kubeman v0.3.0** for managing Kubernetes resources through Python code instead of raw YAML.

### Template Structure

Templates are defined in the `templates/` directory:

- **`airflow_chart.py`** - Airflow Helm chart with embedded values
- **`dog_breeds_db_chart.py`** - PostgreSQL database resources
- **`dog_breeds_api_chart.py`** - FastAPI backend resources

### Rendering Manifests

Manifests are automatically generated during deployment, but you can render them manually:

```bash
# Setup Python environment
uv venv
source .venv/bin/activate
uv pip install -e .

# Render all templates
python -m kubeman render --file render.py

# View generated manifests
ls -R manifests/
```

### Applying Manifests

The `kubeman` CLI can also apply manifests directly:

```bash
# Apply specific namespace resources
python -m kubeman apply --file render.py --namespace dog-breeds

# This is handled automatically by deploy-all.sh
```

## Configuration

### Airflow Configuration

Airflow configuration is managed through `templates/airflow_chart.py`. The `generate_values()` method returns Helm values including:

- **Airflow Version**: 3.1.3
- **Executor**: LocalExecutor
- **Database**: PostgreSQL (bitnami/postgresql:latest)
- **Resources**: Configured for local development
- **Default User**: admin/admin

To customize Airflow settings, edit `templates/airflow_chart.py` and redeploy:

```python
def generate_values(self) -> dict:
    return {
        "airflowVersion": "3.1.3",
        "executor": "LocalExecutor",
        # ... other settings
    }
```

### Changing Executor

To use a different executor, modify `templates/airflow_chart.py`:

```python
def generate_values(self) -> dict:
    return {
        "executor": "CeleryExecutor",  # or "KubernetesExecutor"
        # ... other settings
    }
```

### Changing Default Credentials

Edit the `webserver.defaultUser` section in `templates/airflow_chart.py`:

```python
"webserver": {
    "defaultUser": {
        "username": "your_username",
        "password": "your_password",
        # ... other fields
    },
}
```

## Dog Breeds System

### Overview

The Dog Breeds System demonstrates a complete data pipeline:

1. **Data Ingestion**: Airflow DAG fetches random dog breeds from [Dog API](https://dogapi.dog)
2. **Data Storage**: Breeds stored in PostgreSQL database running in Kubernetes
3. **Data API**: FastAPI backend provides REST API to query breeds
4. **Data Visualization**: React dashboard displays breeds in real-time

### Components

#### 1. Database (PostgreSQL)
- **Location**: `k8s/dog-breeds-db/`
- **Namespace**: `dog-breeds`
- **Service**: `dog-breeds-db.dog-breeds.svc.cluster.local:5432`
- **External Access**: `localhost:30432` (NodePort)
- **Schema**: See `database/schema.sql`

**Features:**
- UUID primary keys
- JSONB for flexible data storage
- Asset URI column linking to Airflow assets
- Indexes for performance (including asset_uri index)
- Views for common queries
- Triggers for automatic timestamps

#### 2. API Backend (FastAPI)
- **Location**: `api/`
- **Namespace**: `dog-breeds`
- **Service**: `dog-breeds-api.dog-breeds.svc.cluster.local:8000`
- **External Access**: `http://localhost:30800` (NodePort)
- **Documentation**: `http://localhost:30800/docs`

**Endpoints:**
- `GET /health` - Health check
- `GET /api/breeds` - List breeds with pagination
- `GET /api/breeds/recent` - Recent breeds (compatible with old API)
- `GET /api/breeds/stats` - Statistics
- `GET /api/breeds/{id}` - Get specific breed
- `GET /api/breeds/search/{name}` - Search by name

#### 3. Airflow DAG
- **Location**: `dags/dog_breed_dag.py`
- **Schedule**: Every hour
- **Tasks**:
  1. `fetch_dog_breed` - Fetch from API and store in database
  2. `print_summary` - Print summary (XCom usage demo)

**Database Connection:**
The DAG uses environment variables to connect:
- `DOG_BREEDS_DB_HOST`
- `DOG_BREEDS_DB_PORT`
- `DOG_BREEDS_DB_NAME`
- `DOG_BREEDS_DB_USER`
- `DOG_BREEDS_DB_PASSWORD`

**Asset-to-Database Connection:**
- Each DAG run creates an Airflow Asset with URI: `dog_breed://dog_breed_fetcher/{dag_run_id}`
- The asset URI is stored in the database `asset_uri` column
- This enables tracking data lineage from Airflow assets to database records
- Asset metadata includes database connection information for easy reference

#### 4. React Dashboard
- **Location**: `dashboard/`
- **Port**: `5173` (Vite dev server)
- **API Connection**: Configured via `VITE_DOG_BREEDS_API_URL`

**Features:**
- Real-time breed display
- Auto-refresh every 30 seconds
- Statistics dashboard
- Responsive design with Tailwind CSS

### Deployment

The recommended approach is to use the unified deployment script:

```bash
./scripts/deploy-all.sh
```

This single script handles:
- ✅ Environment setup (Python venv, kubeman installation)
- ✅ Manifest rendering from templates
- ✅ Airflow Helm deployment with PostgreSQL
- ✅ Database migration (manual, due to Airflow 3.1.3 bug)
- ✅ Dog Breeds PostgreSQL database
- ✅ FastAPI backend (build, load, deploy)
- ✅ Airflow connection configuration

**Deployment Process:**
1. Prerequisites check
2. Python environment setup with `uv`
3. Template rendering with `kubeman`
4. Helm chart deployment
5. Manual migration run (workaround for Airflow bug)
6. Database and API deployment
7. Connection configuration

### Testing the System

#### 1. Test Database Connection
```bash
# From host
psql -h localhost -p 30432 -U airflow -d dog_breeds_db

# List tables
\dt

# Query breeds with asset URIs
SELECT breed_name, asset_uri, life_expectancy, execution_date 
FROM dog_breeds 
ORDER BY execution_date DESC 
LIMIT 10;

# Query breeds by asset URI
SELECT * FROM dog_breeds WHERE asset_uri IS NOT NULL;
```

#### 2. Test API
```bash
# Health check
curl http://localhost:30800/health

# Get recent breeds
curl http://localhost:30800/api/breeds/recent?limit=5

# Get statistics
curl http://localhost:30800/api/breeds/stats

# Open API docs
open http://localhost:30800/docs
```

#### 3. Trigger DAG
```bash
# Via Airflow UI
open http://localhost:8080
# Login (admin/admin), navigate to DAGs, trigger dog_breed_fetcher

# Via CLI
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  airflow dags trigger dog_breed_fetcher
```

#### 4. View Dashboard
```bash
cd dashboard
npm install
npm run dev
open http://localhost:5173
```

### Development Workflow

#### Update API Code
```bash
# Edit api/main.py
vim api/main.py

# Rebuild and redeploy
./scripts/deploy-dog-breeds-api.sh

# View logs
kubectl logs -n dog-breeds -l component=api --tail=50 -f
```

#### Update DAG
```bash
# Edit dags/dog_breed_dag.py
vim dags/dog_breed_dag.py

# Copy updated file to pod (DAGs are in PersistentVolume)
kubectl cp dags/dog_breed_dag.py \
  $(kubectl get pods -n airflow -l component=scheduler -o name | head -1 | cut -d'/' -f2):/opt/airflow/dags/dog_breed_dag.py \
  -n airflow

# DAG processor will reload automatically (usually within 30-60 seconds)
# Check in UI or logs:
kubectl logs -n airflow -l component=dag-processor --tail=50 -f
```

#### Update Dashboard
```bash
# Edit dashboard files
cd dashboard
# Changes hot-reload automatically with Vite
```

#### Update Database Schema
```bash
# Edit database/schema.sql
vim database/schema.sql

# Update schema in running database
kubectl exec -n dog-breeds -it deployment/dog-breeds-db -- \
  psql -U airflow -d dog_breeds_db -f /docker-entrypoint-initdb.d/01-schema.sql

# Or recreate database deployment
kubectl delete deployment dog-breeds-db -n dog-breeds
./scripts/deploy-dog-breeds-db.sh
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

# API Server logs (Airflow 3 uses api-server instead of webserver)
kubectl logs -n airflow -l component=api-server --tail=100

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

## Known Issues

### Airflow 3.1.3 Migration Check Bug

**Issue:** The `wait-for-airflow-migrations` init container may fail with:
```
TimeoutError: There are still unapplied migrations after 60 seconds. 
MigrationHead(s) in DB: {'cc92b33c6709'} | Migration Head(s) in Source Code: {'cc92b33c6709'}
```

**Cause:** This is a bug in Airflow 3.1.3's `check-migrations` command. Even when migration heads match perfectly, the check incorrectly reports unapplied migrations.

**Workaround:** The `deploy-all.sh` script automatically:
1. Disables the Helm chart's built-in migration job
2. Runs migrations manually using a temporary pod
3. Restarts failed pods after migrations complete

**Status:** Pods will initially show `Init:CrashLoopBackOff` but should recover after manual migration. If pods continue failing after 5 minutes, check logs:

```bash
kubectl logs -n airflow -l component=scheduler -c wait-for-airflow-migrations --tail=20
```

The database is healthy if you see matching migration heads in the error message.

## Troubleshooting

### Airflow Issues

#### Port 8080 Already in Use
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

#### Pods Not Starting
```bash
kubectl get pods -n airflow
kubectl describe pod <pod-name> -n airflow
kubectl get events -n airflow --sort-by='.lastTimestamp'
kubectl logs -n airflow <pod-name>
```

#### Database Migration Issues

Due to the Airflow 3.1.3 bug, migrations must be run manually:

```bash
# Run migration in a temporary pod
kubectl run -n airflow airflow-migrations \
  --restart=Never \
  --image=apache/airflow:3.1.3 \
  --env="AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@airflow-postgresql.airflow:5432/airflow" \
  -- airflow db migrate

# Wait for completion
sleep 20

# Check logs
kubectl logs -n airflow airflow-migrations

# Verify migration status
kubectl exec -n airflow airflow-postgresql-0 -- \
  psql -U airflow -d airflow -c "SELECT * FROM alembic_version;"

# Clean up
kubectl delete pod -n airflow airflow-migrations
```

#### DAG Not Showing Up
```bash
# Check DAG processor logs
kubectl logs -n airflow -l component=dag-processor --tail=100

# Check for syntax errors
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  python /opt/airflow/dags/dog_breed_dag.py
```

### Dog Breeds System Issues

#### Database Connection Failed
```bash
# Check database pod status
kubectl get pods -n dog-breeds -l component=database
kubectl logs -n dog-breeds -l component=database --tail=50

# Test connection from Airflow
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  bash -c "psql -h dog-breeds-db.dog-breeds.svc.cluster.local -U airflow -d dog_breeds_db -c 'SELECT 1'"

# Check if ConfigMap exists
kubectl get configmap dog-breeds-db-connection -n airflow
kubectl get secret dog-breeds-db-connection -n airflow
```

#### API Not Responding
```bash
# Check API pods
kubectl get pods -n dog-breeds -l component=api
kubectl logs -n dog-breeds -l component=api --tail=50 -f

# Test API health
curl http://localhost:30800/health

# Check if NodePort service is running
kubectl get svc -n dog-breeds dog-breeds-api-nodeport
```

#### API Image Not Found
```bash
# Rebuild and load image
cd api
docker build -t dog-breeds-api:latest .
kind load docker-image dog-breeds-api:latest --name airflow-cluster

# Restart deployment
kubectl rollout restart deployment/dog-breeds-api -n dog-breeds
```

#### DAG Fails to Store Data
```bash
# Check Airflow logs
kubectl logs -n airflow -l component=scheduler --tail=100 | grep -i error

# Verify environment variables are set
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  bash -c "env | grep DOG_BREEDS"

# Test database connection from Airflow pod
kubectl exec -n airflow -it deployment/airflow-scheduler -- \
  bash -c "python -c 'import psycopg2; conn = psycopg2.connect(host=\"dog-breeds-db.dog-breeds.svc.cluster.local\", port=5432, database=\"dog_breeds_db\", user=\"airflow\", password=\"airflow\"); print(\"Connected!\")'"
```

#### Dashboard Shows No Data
```bash
# Check API is accessible
curl http://localhost:30800/api/breeds/recent?limit=5

# Check browser console for errors
# Make sure VITE_DOG_BREEDS_API_URL is set correctly

# Verify CORS is working
curl -H "Origin: http://localhost:5173" \
  -H "Access-Control-Request-Method: GET" \
  -X OPTIONS http://localhost:30800/api/breeds/recent -v
```

### Kubernetes Issues

#### Kind Cluster Issues
```bash
# Check cluster status
kind get clusters

# Delete and recreate cluster
kind delete cluster --name airflow-cluster
./scripts/setup-kind-cluster.sh

# Check Docker resources
docker system df
```

#### Persistent Volume Issues
```bash
# Check PVCs
kubectl get pvc -n dog-breeds
kubectl describe pvc dog-breeds-db-pvc -n dog-breeds

# Check storage class
kubectl get storageclass
```

#### Image Pull Issues
```bash
# Verify image is loaded in kind
docker exec -it airflow-cluster-control-plane crictl images | grep dog-breeds

# Reload image
kind load docker-image dog-breeds-api:latest --name airflow-cluster
```

### Kubeman Issues

#### Template Rendering Failed
```bash
# Check Python environment
source .venv/bin/activate
python -c "import kubeman; print(kubeman.__version__)"

# Reinstall dependencies
uv pip install -e .

# Render templates with debug output
python -m kubeman render --file render.py

# Check for syntax errors in templates
python -c "from templates import airflow_chart, dog_breeds_db_chart, dog_breeds_api_chart"
```

#### Manifests Not Generated
```bash
# Clean old manifests
rm -rf manifests/

# Render fresh
python -m kubeman render --file render.py

# Check generated files
ls -R manifests/
```

### Helm Issues

#### Helm Chart Update Failed
```bash
# Update Helm repositories
helm repo update apache-airflow

# Check current values (generated from kubeman template)
helm get values airflow -n airflow

# Dry-run upgrade
python -c "from templates.airflow_chart import AirflowChart; import yaml; chart = AirflowChart(); print(yaml.dump(chart.generate_values()))" | \
  helm upgrade airflow apache-airflow/airflow -n airflow --values - --dry-run
```

### Network Issues

#### Services Not Reachable
```bash
# Check services
kubectl get svc -A

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup dog-breeds-db.dog-breeds.svc.cluster.local

# Check endpoints
kubectl get endpoints -n dog-breeds
```

### Complete Reset

If all else fails:
```bash
# Clean everything
./scripts/cleanup.sh

# Wait a moment
sleep 10

# Start fresh
./scripts/start-airflow.sh
./scripts/deploy-all.sh
```

## Architecture

### Components

- **API Server**: Airflow UI and REST API (port 8080) - replaces webserver in Airflow 3
- **Scheduler**: Schedules and triggers tasks
- **Triggerer**: Handles deferred tasks (e.g., sensors)
- **DAG Processor**: Processes DAG files
- **PostgreSQL**: Metadata database (Airflow's internal database)
- **Dog Breeds Database**: External PostgreSQL for storing breed data
- **Redis**: Message broker (only for CeleryExecutor)

### Resources

Default resource limits (suitable for local development):
- API Server: 1 CPU, 2Gi memory
- Scheduler: 1 CPU, 2Gi memory
- Triggerer: 500m CPU, 1Gi memory
- DAG Processor: 500m CPU, 1Gi memory

Adjust in `helm/values.yaml` if needed.

## Asset-to-Database Connection

The system implements a complete data lineage solution by connecting Airflow Assets to PostgreSQL database records:

### How It Works

1. **Asset Creation**: Each DAG run creates an Airflow Asset with URI format:
   ```
   dog_breed://dog_breed_fetcher/{dag_run_id}
   ```

2. **Database Storage**: The asset URI is stored in the `asset_uri` column of the `dog_breeds` table

3. **Metadata Linking**: Asset metadata includes:
   - Database connection information
   - Table and schema details
   - Linked fields (dag_id, dag_run_id, execution_date)

4. **Query Capabilities**: You can now:
   - Query breeds by asset URI
   - Track which asset events correspond to which database records
   - View data lineage in Airflow UI

### Example Queries

```sql
-- Find breeds by asset URI
SELECT * FROM dog_breeds 
WHERE asset_uri = 'dog_breed://dog_breed_fetcher/manual__2025-11-20T22:07:25.403544+00:00_ozkpOpRq';

-- List all breeds with asset URIs
SELECT breed_name, asset_uri, dag_run_id, execution_date 
FROM dog_breeds 
WHERE asset_uri IS NOT NULL 
ORDER BY execution_date DESC;
```

### Viewing in Airflow UI

1. Navigate to **Assets** in the Airflow UI
2. Find the asset: `dog_breed://dog_breed_fetcher`
3. View asset events and lineage
4. Each event links to a database record via the asset URI

## Development

### Template Development

To modify Kubernetes resources, edit the Python templates in `templates/`:

```python
# Example: Add a new ConfigMap to dog_breeds_api_chart.py
self.add_configmap(
    name="new-config",
    namespace="dog-breeds",
    data={"KEY": "value"},
    labels=labels,
)
```

After modifying templates:
```bash
# Render manifests
python -m kubeman render --file render.py

# Apply changes
python -m kubeman apply --file render.py --namespace dog-breeds
```

### Adding New Resources

1. Create a new template class in `templates/`
2. Register it with `@TemplateRegistry.register`
3. Import it in `render.py`
4. Render and apply

## References

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [Airflow 3.1.3 Release Notes](https://airflow.apache.org/docs/apache-airflow/stable/release_notes.html)
- [Airflow Helm Chart Documentation](https://airflow.apache.org/docs/helm-chart/stable/index.html)
- [Airflow Assets Documentation](https://airflow.apache.org/docs/apache-airflow/stable/concepts/assets.html)
- [kind Documentation](https://kind.sigs.k8s.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [kubeman Documentation](https://github.com/your-org/kubeman) (v0.3.0)

## License

This setup uses Apache Airflow, which is licensed under the Apache License 2.0.
