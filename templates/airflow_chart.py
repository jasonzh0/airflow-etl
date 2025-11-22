"""Airflow Helm chart definition using kubeman."""
from kubeman import HelmChart, TemplateRegistry


@TemplateRegistry.register
class AirflowChart(HelmChart):
    """Apache Airflow Helm chart configuration."""

    @property
    def name(self) -> str:
        return "airflow"

    @property
    def repository(self) -> dict:
        """Return repository information for Apache Airflow Helm chart."""
        return {
            "type": "classic",
            "remote": "https://airflow.apache.org",
        }

    @property
    def repository_package(self) -> str:
        """The Helm chart package name."""
        return "airflow"

    @property
    def namespace(self) -> str:
        return "airflow"

    @property
    def version(self) -> str:
        """Helm chart version (not the Airflow app version)."""
        return "1.18.0"

    def generate_values(self) -> dict:
        """Generate values.yaml content for Airflow Helm chart."""
        return {
            "airflowVersion": "3.1.3",
            "defaultAirflowRepository": "apache/airflow",
            "defaultAirflowTag": "3.1.3",
            "executor": "LocalExecutor",
            "postgresql": {
                "enabled": True,
                "image": {
                    "registry": "docker.io",
                    "repository": "postgres",
                    "tag": "16-alpine",
                },
                "auth": {
                    "username": "airflow",
                    "password": "airflow",
                    "database": "airflow",
                },
            },
            "webserver": {
                "defaultUser": {
                    "enabled": True,
                    "username": "admin",
                    "password": "admin",
                    "email": "admin@example.com",
                    "firstName": "Admin",
                    "lastName": "User",
                    "role": "Admin",
                },
            },
            "resources": {
                "webserver": {
                    "requests": {
                        "memory": "512Mi",
                        "cpu": "200m",
                    },
                    "limits": {
                        "memory": "1Gi",
                        "cpu": "500m",
                    },
                },
                "scheduler": {
                    "requests": {
                        "memory": "512Mi",
                        "cpu": "200m",
                    },
                    "limits": {
                        "memory": "1Gi",
                        "cpu": "500m",
                    },
                },
            },
        }

