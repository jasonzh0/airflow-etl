#!/usr/bin/env python3
"""Template registration file for kubeman CLI."""
import os
import shutil
import sys
from pathlib import Path

# Add templates to path
sys.path.insert(0, str(Path(__file__).parent))

# Set environment variables for kubeman
os.environ.setdefault("ARGOCD_APP_REPO_URL", "https://github.com/dummy/manifests-repo")
os.environ.setdefault("STABLE_GIT_BRANCH", "main")
os.environ.setdefault("STABLE_GIT_COMMIT", "test")

# Import all templates to register them
from templates import airflow_chart, dog_breeds_db_chart, dog_breeds_api_chart  # noqa: F401

# If run directly (not via kubeman CLI), copy manifests to project root
if __name__ == "__main__":
    from kubeman.template import Template
    
    # Clean up old manifests
    venv_manifests = Path(__file__).parent / ".venv" / "lib" / "python3.13" / "manifests"
    if venv_manifests.exists():
        shutil.rmtree(venv_manifests)
    
    project_manifests = Path(__file__).parent / "manifests"
    if project_manifests.exists():
        shutil.rmtree(project_manifests)
    
    # Copy manifests from venv to project root after rendering
    # This is handled by the deploy script after kubeman CLI runs

