#!/bin/bash

# KLDP - Check Prerequisites
# This script checks if all required tools are installed and provides installation instructions

echo "🔍 Checking KLDP Prerequisites..."
echo ""

MISSING_TOOLS=()

# Function to check if a command exists
check_command() {
    local cmd=$1
    local name=$2
    local install_url=$3

    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd version 2>&1 | head -n 1 || echo "installed")
        echo "✅ $name: $version"
        return 0
    else
        echo "❌ $name: Not found"
        MISSING_TOOLS+=("$name|$install_url")
        return 1
    fi
}

# Check Docker
check_command "docker" "Docker" "https://docs.docker.com/get-docker/"

# Check Minikube
check_command "minikube" "Minikube" "https://minikube.sigs.k8s.io/docs/start/"

# Check kubectl
check_command "kubectl" "kubectl" "https://kubernetes.io/docs/tasks/tools/"

# Check Helm
check_command "helm" "Helm" "https://helm.sh/docs/intro/install/"

# Check Python
if command -v python3 &> /dev/null; then
    python_version=$(python3 --version)
    echo "✅ Python: $python_version"

    # Check if Airflow is installed
    if python3 -c "import airflow" 2>/dev/null; then
        airflow_version=$(python3 -c "import airflow; print(airflow.__version__)")
        echo "✅ Airflow: $airflow_version (for local DAG testing)"
    else
        echo "⚠️  Airflow: Not installed (optional for local DAG testing)"
        echo "   Install with: pip install -r requirements-dev.txt"
    fi
else
    echo "❌ Python: Not found"
    MISSING_TOOLS+=("Python|https://www.python.org/downloads/")
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"

# Summary
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo "✨ All prerequisites are installed!"
    echo ""
    echo "Next steps:"
    echo "  1. Initialize cluster: ./scripts/init-cluster.sh"
    echo "  2. Install Airflow: ./scripts/install-airflow.sh"
    echo ""
    echo "Optional (for local DAG testing):"
    echo "  pip install -r requirements-dev.txt"
else
    echo "❌ Missing ${#MISSING_TOOLS[@]} tool(s). Please install them:"
    echo ""
    for tool in "${MISSING_TOOLS[@]}"; do
        IFS='|' read -r name url <<< "$tool"
        echo "  📦 $name"
        echo "     $url"
        echo ""
    done
fi
