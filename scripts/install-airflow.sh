#!/bin/bash
set -e

# KLDP - Install Apache Airflow
# Installs Airflow with KubernetesExecutor optimized for local development

NAMESPACE="airflow"
RELEASE_NAME="airflow"
CHART_VERSION=${KLDP_AIRFLOW_VERSION:-"1.18.0"}

echo "🚀 Installing Apache Airflow..."
echo "  Namespace: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo "  Chart Version: $CHART_VERSION"
echo ""

# Check if cluster is running
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Error: Kubernetes cluster is not accessible"
    echo "Run: ./scripts/init-cluster.sh"
    exit 1
fi

# Add Airflow Helm repo
echo "📦 Adding Airflow Helm repository..."
helm repo add apache-airflow https://airflow.apache.org
helm repo update

# Check if already installed
if helm list -n $NAMESPACE | grep -q "^$RELEASE_NAME"; then
    echo "⚠️  Airflow is already installed"
    read -p "Do you want to upgrade it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "⬆️  Upgrading Airflow..."
        helm upgrade $RELEASE_NAME apache-airflow/airflow \
            --namespace $NAMESPACE \
            --values ../core/airflow/values.yaml \
            --version $CHART_VERSION
    else
        echo "Skipping installation"
        exit 0
    fi
else
    # Install Airflow
    echo "📥 Installing Airflow..."
    helm install $RELEASE_NAME apache-airflow/airflow \
        --namespace $NAMESPACE \
        --create-namespace \
        --values ../core/airflow/values.yaml \
        --version $CHART_VERSION
fi

echo ""
echo "⏳ Waiting for Airflow to be ready..."
kubectl wait --for=condition=ready pod \
    -l component=webserver \
    -n $NAMESPACE \
    --timeout=300s

echo ""
echo "✅ Airflow installed successfully!"
echo ""
echo "📊 Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "🌐 Access Airflow UI:"
echo "  Option 1: kubectl port-forward svc/$RELEASE_NAME-webserver 8080:8080 -n $NAMESPACE"
echo "  Option 2: minikube service $RELEASE_NAME-webserver -n $NAMESPACE"
echo ""
echo "📂 Add your DAGs to: ./examples/dags/"
echo ""
echo "Useful commands:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE -l component=webserver -f"
echo "  helm status $RELEASE_NAME -n $NAMESPACE"