#!/bin/bash
set -e

# KLDP - Initialize Minikube Cluster
# This script creates and configures a minikube cluster optimized for data workloads

CLUSTER_NAME="kldp"
CPUS=${KLDP_CPUS:-4}
MEMORY=${KLDP_MEMORY:-8192}
DISK_SIZE=${KLDP_DISK:-40g}
K8S_VERSION=${KLDP_K8S_VERSION:-v1.30.0}

echo "🚀 Initializing KLDP Cluster..."
echo "  Name: $CLUSTER_NAME"
echo "  CPUs: $CPUS"
echo "  Memory: ${MEMORY}MB"
echo "  Disk: $DISK_SIZE"
echo "  Kubernetes: $K8S_VERSION"
echo ""

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ Error: minikube is not installed"
    echo "Install from: https://minikube.sigs.k8s.io/docs/start/"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is not installed"
    echo "Install from: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "❌ Error: helm is not installed"
    echo "Install from: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if cluster already exists
if minikube profile list 2>/dev/null | grep -q "^| $CLUSTER_NAME "; then
    echo "⚠️  Cluster '$CLUSTER_NAME' already exists"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Deleting existing cluster..."
        minikube delete -p $CLUSTER_NAME
    else
        echo "✅ Using existing cluster"
        minikube profile $CLUSTER_NAME
        exit 0
    fi
fi

# Create minikube cluster
echo "📦 Creating minikube cluster..."
minikube start \
    --profile=$CLUSTER_NAME \
    --cpus=$CPUS \
    --memory=$MEMORY \
    --disk-size=$DISK_SIZE \
    --kubernetes-version=$K8S_VERSION \
    --driver=docker \
    --addons=default-storageclass,storage-provisioner,metrics-server

# Set as default profile
minikube profile $CLUSTER_NAME

# Verify cluster is running
echo ""
echo "✅ Cluster created successfully!"
echo ""

# Display cluster info
kubectl cluster-info
echo ""
kubectl get nodes
echo ""

# Create namespaces
echo "📁 Creating namespaces..."
kubectl create namespace airflow --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace spark --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace storage --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "✨ KLDP cluster is ready!"
echo ""
echo "Next steps:"
echo "  1. Install Airflow: ./scripts/install-airflow.sh"
echo "  2. Install Spark: ./scripts/install-spark.sh"
echo "  3. Or install everything: ./scripts/install-all.sh"
echo ""
echo "Useful commands:"
echo "  minikube dashboard -p $CLUSTER_NAME"
echo "  kubectl get pods -A"
echo "  minikube profile $CLUSTER_NAME"