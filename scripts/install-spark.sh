#!/bin/bash

# KLDP - Install Spark Operator on Kubernetes
# This script installs Kubeflow Spark Operator using Helm

set -e

echo "🚀 Installing Spark Operator"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the project root directory (parent of scripts)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

VALUES_FILE="$PROJECT_ROOT/core/compute/spark-operator-values.yaml"

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: Spark Operator values file not found at $VALUES_FILE"
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

# Check if spark namespace exists, create if not
if ! kubectl get namespace spark &> /dev/null; then
    echo "Creating spark namespace..."
    kubectl create namespace spark
fi

echo "Adding Kubeflow Spark Operator Helm repository..."
helm repo add spark-operator https://kubeflow.github.io/spark-operator
helm repo update

echo ""
echo "Installing Spark Operator..."
echo "Using values file: $VALUES_FILE"

# Get Spark Operator version from environment or use default
SPARK_OPERATOR_VERSION=${KLDP_SPARK_OPERATOR_VERSION:-""}

# Build helm install command
HELM_CMD="helm install spark-operator spark-operator/spark-operator \
    --namespace spark \
    --values \"$VALUES_FILE\" \
    --wait \
    --timeout 10m"

# Add version if specified
if [ -n "$SPARK_OPERATOR_VERSION" ]; then
    HELM_CMD="$HELM_CMD --version \"$SPARK_OPERATOR_VERSION\""
fi

# Execute helm install
eval $HELM_CMD

echo ""
echo "✅ Spark Operator installation complete!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Spark Operator Information:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Namespace: spark"
echo ""
echo "Check operator status:"
echo "  kubectl get pods -n spark"
echo ""
echo "View operator logs:"
echo "  kubectl logs -n spark -l app.kubernetes.io/name=spark-operator -f"
echo ""
echo "Create a Spark application:"
echo "  kubectl apply -f examples/spark/spark-pi.yaml"
echo ""
echo "List Spark applications:"
echo "  kubectl get sparkapplications -n spark"
echo ""
echo "View application status:"
echo "  kubectl describe sparkapplication <app-name> -n spark"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Verify operator is running: kubectl get pods -n spark"
echo "  2. Run example Spark job: kubectl apply -f examples/spark/spark-pi.yaml"
echo "  3. Integrate with Airflow: See examples/dags/example_spark_job.py"
echo ""
