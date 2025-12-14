#!/bin/bash

# KLDP - Install Prometheus/Grafana Monitoring Stack
# This script installs kube-prometheus-stack using Helm

set -e

echo "🚀 Installing Prometheus/Grafana Monitoring Stack"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the project root directory (parent of scripts)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

VALUES_FILE="$PROJECT_ROOT/core/monitoring/prometheus-grafana-values.yaml"

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
    echo "❌ Error: Monitoring values file not found at $VALUES_FILE"
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

# Check if monitoring namespace exists, create if not
if ! kubectl get namespace monitoring &> /dev/null; then
    echo "Creating monitoring namespace..."
    kubectl create namespace monitoring
fi

echo "Adding Prometheus Community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

echo ""
echo "Installing kube-prometheus-stack..."
echo "Using values file: $VALUES_FILE"
echo ""
echo "This may take a few minutes as it installs multiple components:"
echo "  - Prometheus Operator"
echo "  - Prometheus Server"
echo "  - Alertmanager"
echo "  - Grafana"
echo "  - Node Exporter"
echo "  - Kube State Metrics"
echo ""

# Get version from environment or use default
MONITORING_VERSION=${KLDP_MONITORING_VERSION:-""}

# Build helm install command
HELM_CMD="helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --values \"$VALUES_FILE\" \
    --wait \
    --timeout 15m"

# Add version if specified
if [ -n "$MONITORING_VERSION" ]; then
    HELM_CMD="$HELM_CMD --version \"$MONITORING_VERSION\""
fi

# Execute helm install
eval $HELM_CMD

echo ""
echo "✅ Monitoring stack installation complete!"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Prometheus/Grafana Access Information:"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Grafana Dashboard:"
echo "  kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring"
echo "  Then access at: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Prometheus UI:"
echo "  kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring"
echo "  Then access at: http://localhost:9090"
echo ""
echo "Alertmanager UI:"
echo "  kubectl port-forward svc/kube-prometheus-stack-alertmanager 9093:9093 -n monitoring"
echo "  Then access at: http://localhost:9093"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Useful Commands:"
echo "  # Check all monitoring pods"
echo "  kubectl get pods -n monitoring"
echo ""
echo "  # View Prometheus targets"
echo "  # Access Prometheus UI and go to Status > Targets"
echo ""
echo "  # Import custom dashboards in Grafana"
echo "  # Access Grafana UI and go to Dashboards > Import"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Next steps:"
echo "  1. Port forward Grafana: kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring"
echo "  2. Access Grafana at http://localhost:3000 (admin/admin)"
echo "  3. Explore pre-installed dashboards for Kubernetes monitoring"
echo "  4. Check docs/MONITORING_SETUP.md for custom dashboards"
echo ""
