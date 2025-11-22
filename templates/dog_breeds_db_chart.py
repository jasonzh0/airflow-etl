"""Dog Breeds Database chart definition using kubeman."""
from pathlib import Path
from kubeman import KubernetesResource, TemplateRegistry


@TemplateRegistry.register
class DogBreedsDbChart(KubernetesResource):
    """Dog Breeds PostgreSQL database resources."""

    @property
    def name(self) -> str:
        return "dog-breeds-db"

    @property
    def namespace(self) -> str:
        return "dog-breeds"

    def __init__(self):
        super().__init__()

        # Load schema file
        schema_file = Path(__file__).parent.parent / "database" / "schema.sql"
        schema_content = ""
        if schema_file.exists():
            schema_content = schema_file.read_text()

        labels = {
            "app": "dog-breeds",
            "component": "database",
        }

        # Add Namespace
        self.add_namespace(
            name="dog-breeds",
            labels=labels,
        )

        # Add ConfigMap for database configuration
        self.add_configmap(
            name="dog-breeds-db-config",
            namespace="dog-breeds",
            data={
                "POSTGRES_DB": "dog_breeds_db",
                "POSTGRES_USER": "airflow",
            },
            labels=labels,
        )

        # Add Secret for database password
        self.add_secret(
            name="dog-breeds-db-secret",
            namespace="dog-breeds",
            string_data={
                "POSTGRES_PASSWORD": "airflow",
                "DATABASE_URL": "postgresql://airflow:airflow@dog-breeds-db.dog-breeds.svc.cluster.local:5432/dog_breeds_db",
            },
            labels=labels,
        )

        # Add PersistentVolumeClaim
        self.add_persistent_volume_claim(
            name="dog-breeds-db-pvc",
            namespace="dog-breeds",
            access_modes=["ReadWriteOnce"],
            storage="5Gi",
            labels=labels,
        )

        # Add Schema ConfigMap
        self.add_configmap(
            name="dog-breeds-db-schema",
            namespace="dog-breeds",
            data={
                "01-schema.sql": schema_content,
            },
            labels=labels,
        )

        # Add Deployment
        self.add_deployment(
            name="dog-breeds-db",
            namespace="dog-breeds",
            replicas=1,
            strategy_type="Recreate",
            labels=labels,
            containers=[
                {
                    "name": "postgres",
                    "image": "postgres:16-alpine",
                    "imagePullPolicy": "IfNotPresent",
                    "ports": [
                        {
                            "name": "postgres",
                            "containerPort": 5432,
                            "protocol": "TCP",
                        },
                    ],
                    "env": [
                        {
                            "name": "POSTGRES_DB",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-db-config",
                                    "key": "POSTGRES_DB",
                                },
                            },
                        },
                        {
                            "name": "POSTGRES_USER",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-db-config",
                                    "key": "POSTGRES_USER",
                                },
                            },
                        },
                        {
                            "name": "POSTGRES_PASSWORD",
                            "valueFrom": {
                                "secretKeyRef": {
                                    "name": "dog-breeds-db-secret",
                                    "key": "POSTGRES_PASSWORD",
                                },
                            },
                        },
                        {
                            "name": "PGDATA",
                            "value": "/var/lib/postgresql/data/pgdata",
                        },
                    ],
                    "volumeMounts": [
                        {
                            "name": "postgres-storage",
                            "mountPath": "/var/lib/postgresql/data",
                        },
                        {
                            "name": "schema",
                            "mountPath": "/docker-entrypoint-initdb.d",
                            "readOnly": True,
                        },
                    ],
                    "resources": {
                        "requests": {
                            "memory": "256Mi",
                            "cpu": "250m",
                        },
                        "limits": {
                            "memory": "512Mi",
                            "cpu": "500m",
                        },
                    },
                    "livenessProbe": {
                        "exec": {
                            "command": [
                                "/bin/sh",
                                "-c",
                                "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB",
                            ],
                        },
                        "initialDelaySeconds": 30,
                        "periodSeconds": 10,
                        "timeoutSeconds": 5,
                        "failureThreshold": 3,
                    },
                    "readinessProbe": {
                        "exec": {
                            "command": [
                                "/bin/sh",
                                "-c",
                                "pg_isready -U $POSTGRES_USER -d $POSTGRES_DB",
                            ],
                        },
                        "initialDelaySeconds": 10,
                        "periodSeconds": 5,
                        "timeoutSeconds": 3,
                        "failureThreshold": 3,
                    },
                },
            ],
            volumes=[
                {
                    "name": "postgres-storage",
                    "persistentVolumeClaim": {
                        "claimName": "dog-breeds-db-pvc",
                    },
                },
                {
                    "name": "schema",
                    "configMap": {
                        "name": "dog-breeds-db-schema",
                    },
                },
            ],
        )

        # Add ClusterIP Service
        self.add_service(
            name="dog-breeds-db",
            namespace="dog-breeds",
            service_type="ClusterIP",
            selector={
                "app": "dog-breeds",
                "component": "database",
            },
            ports=[
                {
                    "name": "postgres",
                    "port": 5432,
                    "targetPort": 5432,
                    "protocol": "TCP",
                },
            ],
            labels=labels,
        )

        # Add NodePort Service for external access
        self.add_service(
            name="dog-breeds-db-nodeport",
            namespace="dog-breeds",
            service_type="NodePort",
            selector={
                "app": "dog-breeds",
                "component": "database",
            },
            ports=[
                {
                    "name": "postgres",
                    "port": 5432,
                    "targetPort": 5432,
                    "nodePort": 30432,
                    "protocol": "TCP",
                },
            ],
            labels=labels,
        )
