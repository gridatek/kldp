#!/bin/bash

# KLDP - Install MinIO on Kubernetes
# This script installs MinIO object storage using Helm

set -e

echo "🚀 Installing MinIO Object Storage"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the project root directory (parent of scripts)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Allow override of values file via environment variable (for CI)
VALUES_FILE="${KLDP_MINIO_VALUES_FILE:-$PROJECT_ROOT/core/storage/minio-values.yaml}"

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: MinIO values file not found at $VALUES_FILE"
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Error: Helm is not installed or not in PATH"
    exit 1
fi

# Check if storage namespace exists, create if not
if ! kubectl get namespace storage &> /dev/null; then
    echo "Creating storage namespace..."
    kubectl create namespace storage
fi

echo "Installing MinIO from OCI registry..."
echo "Using values file: $VALUES_FILE"

# Get MinIO version from environment or use default
MINIO_VERSION=${KLDP_MINIO_VERSION:-"17.0.21"}

# Install from OCI registry (Bitnami charts now use OCI format)
helm install minio oci://registry-1.docker.io/bitnamicharts/minio \
    --namespace storage \
    --values "$VALUES_FILE" \
    --version "$MINIO_VERSION" \
    --wait \
    --timeout 15m

echo ""
echo "✅ MinIO installation complete!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "MinIO Access Information:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "API Endpoint (S3):"
echo "  kubectl port-forward svc/minio 9000:9000 -n storage"
echo "  Then access at: http://localhost:9000"
echo ""
echo "Console UI (Web Interface):"
echo "  kubectl port-forward svc/minio 9001:9001 -n storage"
echo "  Then access at: http://localhost:9001"
echo ""
echo "Credentials:"
echo "  Username: minioadmin"
echo "  Password: minioadmin"
echo ""
echo "Default Buckets:"
echo "  - datalake (general purpose)"
echo "  - raw (raw/landing data)"
echo "  - processed (transformed data)"
echo "  - curated (business-ready data)"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Port forward the console: kubectl port-forward svc/minio 9001:9001 -n storage"
echo "  2. Access MinIO Console at http://localhost:9001"
echo "  3. Run example S3 DAG: examples/dags/example_minio_s3.py"
echo ""
