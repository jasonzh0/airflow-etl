#!/bin/bash

# Generate Kubernetes templates from Airflow Helm chart
# This script generates YAML templates that can be reviewed before deployment

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HELM_DIR="$PROJECT_DIR/helm"
OUTPUT_DIR="$PROJECT_DIR/k8s/airflow"

echo "=================================================="
echo "Generate Airflow Helm Templates"
echo "=================================================="
echo ""

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm not found. Please install Helm."
    exit 1
fi

echo "✅ Helm found: $(helm version --short)"
echo ""

# Add Airflow Helm repository if not already added
if ! helm repo list | grep -q "apache-airflow"; then
    echo "Adding Apache Airflow Helm repository..."
    helm repo add apache-airflow https://airflow.apache.org
fi

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

echo ""
echo "Generating Kubernetes templates..."
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate templates
helm template airflow apache-airflow/airflow \
  --namespace airflow \
  --values "$HELM_DIR/values.yaml" \
  --output-dir "$OUTPUT_DIR"

# Move generated files to the output directory root
if [ -d "$OUTPUT_DIR/airflow/templates" ]; then
    mv "$OUTPUT_DIR/airflow/templates"/* "$OUTPUT_DIR/" 2>/dev/null || true
    rm -rf "$OUTPUT_DIR/airflow"
fi

echo ""
echo "=================================================="
echo "✅ Templates Generated Successfully!"
echo "=================================================="
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
echo "Generated files:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "Review the generated templates before applying:"
echo "  ls $OUTPUT_DIR"
echo ""
echo "Apply all templates:"
echo "  kubectl apply -f $OUTPUT_DIR"
echo ""
echo "Apply specific template:"
echo "  kubectl apply -f $OUTPUT_DIR/<filename>"
echo ""

