#!/bin/bash

# KLDP - Install Prerequisites for Fedora Linux
# This script installs kubectl, Minikube, and Helm on Fedora

set -e

echo "🚀 Installing KLDP Prerequisites for Fedora Linux"
echo ""

# Check if running on Fedora
if [ ! -f /etc/fedora-release ]; then
    echo "⚠️  Warning: This script is designed for Fedora Linux"
    echo "You're running: $(uname -a)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "═══════════════════════════════════════════════════════════════"
echo "1/4 Installing kubectl..."
echo "═══════════════════════════════════════════════════════════════"

if command -v kubectl &> /dev/null; then
    echo "✅ kubectl already installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
else
    echo "Installing kubectl via dnf..."
    sudo dnf install -y kubectl
    echo "✅ kubectl installed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "2/4 Installing Minikube..."
echo "═══════════════════════════════════════════════════════════════"

if command -v minikube &> /dev/null; then
    echo "✅ Minikube already installed: $(minikube version --short)"
else
    echo "Downloading Minikube RPM..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm

    echo "Installing Minikube..."
    sudo rpm -Uvh minikube-latest.x86_64.rpm

    echo "Cleaning up..."
    rm minikube-latest.x86_64.rpm

    echo "✅ Minikube installed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "3/4 Installing Helm..."
echo "═══════════════════════════════════════════════════════════════"

if command -v helm &> /dev/null; then
    echo "✅ Helm already installed: $(helm version --short)"
else
    echo "Installing Helm using official script..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    echo "✅ Helm installed"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "4/4 Configuring Docker..."
echo "═══════════════════════════════════════════════════════════════"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed!"
    echo "Install Docker with: sudo dnf install -y docker"
    echo "Then run: sudo systemctl start docker && sudo systemctl enable docker"
    exit 1
fi

# Check if Docker daemon is running
if ! sudo systemctl is-active --quiet docker; then
    echo "Starting Docker daemon..."
    sudo systemctl start docker
    sudo systemctl enable docker
    echo "✅ Docker daemon started"
else
    echo "✅ Docker daemon is running"
fi

# Add user to docker group
if groups $USER | grep -q '\bdocker\b'; then
    echo "✅ User $USER is already in docker group"
else
    echo "Adding $USER to docker group..."
    sudo usermod -aG docker $USER
    echo "✅ User added to docker group"
    echo ""
    echo "⚠️  IMPORTANT: You must log out and back in for group changes to take effect!"
    echo "   Or run: newgrp docker"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "✨ Installation Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Verify installations
echo "Installed versions:"
echo "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client | head -n1)"
echo "  minikube: $(minikube version --short)"
echo "  helm: $(helm version --short)"
echo "  docker: $(docker --version)"
echo ""

echo "Next steps:"
echo "  1. If you were added to docker group, log out and back in (or run: newgrp docker)"
echo "  2. Verify prerequisites: ./scripts/check-prerequisites.sh"
echo "  3. Initialize cluster: ./scripts/init-cluster.sh"
echo "  4. Install Airflow: ./scripts/install-airflow.sh"
echo ""
