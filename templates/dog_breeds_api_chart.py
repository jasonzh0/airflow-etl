"""Dog Breeds API chart definition using kubeman."""
from kubeman import KubernetesResource, TemplateRegistry


@TemplateRegistry.register
class DogBreedsApiChart(KubernetesResource):
    """Dog Breeds FastAPI backend resources."""

    @property
    def name(self) -> str:
        return "dog-breeds-api"

    @property
    def namespace(self) -> str:
        return "dog-breeds"

    def __init__(self):
        super().__init__()

        labels = {
            "app": "dog-breeds",
            "component": "api",
        }

        # Add ConfigMap for API configuration
        self.add_configmap(
            name="dog-breeds-api-config",
            namespace="dog-breeds",
            data={
                "DOG_BREEDS_DB_HOST": "dog-breeds-db.dog-breeds.svc.cluster.local",
                "DOG_BREEDS_DB_PORT": "5432",
                "DOG_BREEDS_DB_NAME": "dog_breeds_db",
                "DOG_BREEDS_DB_USER": "airflow",
                "API_HOST": "0.0.0.0",
                "API_PORT": "8000",
                "ALLOWED_ORIGINS": "*",
            },
            labels=labels,
        )

        # Add Deployment with initContainers
        self.add_deployment(
            name="dog-breeds-api",
            namespace="dog-breeds",
            replicas=2,
            strategy_type="RollingUpdate",
            labels=labels,
            init_containers=[
                {
                    "name": "wait-for-db",
                    "image": "postgres:16-alpine",
                    "command": [
                        "sh",
                        "-c",
                        "until pg_isready -h $DOG_BREEDS_DB_HOST -p $DOG_BREEDS_DB_PORT -U $DOG_BREEDS_DB_USER; do echo 'Waiting for database...'; sleep 2; done; echo 'Database is ready!'",
                    ],
                    "env": [
                        {
                            "name": "DOG_BREEDS_DB_HOST",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_HOST",
                                },
                            },
                        },
                        {
                            "name": "DOG_BREEDS_DB_PORT",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_PORT",
                                },
                            },
                        },
                        {
                            "name": "DOG_BREEDS_DB_USER",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_USER",
                                },
                            },
                        },
                    ],
                },
            ],
            containers=[
                {
                    "name": "api",
                    "image": "dog-breeds-api:latest",
                    "imagePullPolicy": "IfNotPresent",
                    "ports": [
                        {
                            "name": "http",
                            "containerPort": 8000,
                            "protocol": "TCP",
                        },
                    ],
                    "env": [
                        {
                            "name": "DOG_BREEDS_DB_HOST",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_HOST",
                                },
                            },
                        },
                        {
                            "name": "DOG_BREEDS_DB_PORT",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_PORT",
                                },
                            },
                        },
                        {
                            "name": "DOG_BREEDS_DB_NAME",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_NAME",
                                },
                            },
                        },
                        {
                            "name": "DOG_BREEDS_DB_USER",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "DOG_BREEDS_DB_USER",
                                },
                            },
                        },
                        {
                            "name": "DOG_BREEDS_DB_PASSWORD",
                            "valueFrom": {
                                "secretKeyRef": {
                                    "name": "dog-breeds-db-secret",
                                    "key": "POSTGRES_PASSWORD",
                                },
                            },
                        },
                        {
                            "name": "API_HOST",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "API_HOST",
                                },
                            },
                        },
                        {
                            "name": "API_PORT",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "API_PORT",
                                },
                            },
                        },
                        {
                            "name": "ALLOWED_ORIGINS",
                            "valueFrom": {
                                "configMapKeyRef": {
                                    "name": "dog-breeds-api-config",
                                    "key": "ALLOWED_ORIGINS",
                                },
                            },
                        },
                    ],
                    "resources": {
                        "requests": {
                            "memory": "128Mi",
                            "cpu": "100m",
                        },
                        "limits": {
                            "memory": "256Mi",
                            "cpu": "500m",
                        },
                    },
                    "livenessProbe": {
                        "httpGet": {
                            "path": "/health",
                            "port": 8000,
                        },
                        "initialDelaySeconds": 15,
                        "periodSeconds": 20,
                        "timeoutSeconds": 5,
                        "failureThreshold": 3,
                    },
                    "readinessProbe": {
                        "httpGet": {
                            "path": "/health",
                            "port": 8000,
                        },
                        "initialDelaySeconds": 10,
                        "periodSeconds": 10,
                        "timeoutSeconds": 3,
                        "failureThreshold": 3,
                    },
                },
            ],
        )

        # Add ClusterIP Service
        self.add_service(
            name="dog-breeds-api",
            namespace="dog-breeds",
            service_type="ClusterIP",
            selector={
                "app": "dog-breeds",
                "component": "api",
            },
            ports=[
                {
                    "name": "http",
                    "port": 8000,
                    "targetPort": 8000,
                    "protocol": "TCP",
                },
            ],
            labels=labels,
        )

        # Add NodePort Service for external access
        self.add_service(
            name="dog-breeds-api-nodeport",
            namespace="dog-breeds",
            service_type="NodePort",
            selector={
                "app": "dog-breeds",
                "component": "api",
            },
            ports=[
                {
                    "name": "http",
                    "port": 8000,
                    "targetPort": 8000,
                    "nodePort": 30800,
                    "protocol": "TCP",
                },
            ],
            labels=labels,
        )

        # Add Ingress
        self.add_ingress(
            name="dog-breeds-api",
            namespace="dog-breeds",
            ingress_class_name="nginx",
            rules=[
                {
                    "host": "dog-breeds-api.local",
                    "paths": [
                        {
                            "path": "/",
                            "pathType": "Prefix",
                            "backend": {
                                "service": {
                                    "name": "dog-breeds-api",
                                    "port": {
                                        "number": 8000,
                                    },
                                },
                            },
                        },
                    ],
                },
            ],
            annotations={
                "nginx.ingress.kubernetes.io/rewrite-target": "/",
                "nginx.ingress.kubernetes.io/cors-allow-origin": "*",
                "nginx.ingress.kubernetes.io/cors-allow-methods": "GET, POST, PUT, DELETE, OPTIONS",
                "nginx.ingress.kubernetes.io/cors-allow-headers": "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization",
            },
            labels=labels,
        )
