# Installing KLDP Prerequisites on Fedora Linux

This guide provides step-by-step instructions for installing the required tools to run KLDP on Fedora Linux.

## Prerequisites Status

Run this to check what you need:
```bash
./scripts/check-prerequisites.sh
```

## Installation Instructions for Fedora

### 1. Install kubectl

**Option A: Using Fedora package manager (Recommended)**
```bash
sudo dnf install -y kubectl
```

**Option B: Using official Kubernetes repository**
```bash
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repokey.gpg
EOF

# Install kubectl
sudo dnf install -y kubectl
```

**Verify installation:**
```bash
kubectl version --client
```

### 2. Install Minikube

**Option A: Using RPM package (Recommended)**
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
sudo rpm -Uvh minikube-latest.x86_64.rpm
rm minikube-latest.x86_64.rpm
```

**Option B: Using binary download**
```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64
```

**Verify installation:**
```bash
minikube version
```

### 3. Install Helm

**Option A: Using official script (Recommended)**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Option B: Using Fedora package manager**
```bash
sudo dnf install -y helm
```

**Option C: Manual binary installation**
```bash
curl -LO https://get.helm.sh/helm-v3.14.0-linux-amd64.tar.gz
tar -zxvf helm-v3.14.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf linux-amd64 helm-v3.14.0-linux-amd64.tar.gz
```

**Verify installation:**
```bash
helm version
```

### 4. Verify Docker is Running

You already have Docker installed. Make sure it's running:
```bash
# Check if Docker daemon is running
sudo systemctl status docker

# If not running, start it
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group (avoids needing sudo for docker commands)
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
# Or run: newgrp docker
```

### 5. Install Python Development Dependencies (Optional)

For local DAG testing without running the full cluster:
```bash
# Install pip if not available
sudo dnf install -y python3-pip

# Install Airflow and development tools
pip install -r requirements-dev.txt \
  --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-3.1.0/constraints-3.12.txt"
```

Note: You're running Python 3.14.2, but Airflow 3.1.0 officially supports Python 3.12. You may encounter compatibility issues. Consider using Python 3.12 in a virtual environment:
```bash
# Create virtual environment with Python 3.12 if available
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt \
  --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-3.1.0/constraints-3.12.txt"
```

## Quick Install Script

Install all tools at once:
```bash
# kubectl
sudo dnf install -y kubectl

# Minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-latest.x86_64.rpm
sudo rpm -Uvh minikube-latest.x86_64.rpm
rm minikube-latest.x86_64.rpm

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installations
echo "Checking installations..."
kubectl version --client
minikube version
helm version

# Make sure Docker group is set
sudo usermod -aG docker $USER
echo "⚠️  Please log out and back in for Docker group changes to take effect"
```

## Verify All Prerequisites

After installation, run:
```bash
./scripts/check-prerequisites.sh
```

You should see all tools marked with ✅.

## Next Steps

Once all prerequisites are installed:
```bash
# 1. Initialize the cluster
./scripts/init-cluster.sh

# 2. Install Airflow
./scripts/install-airflow.sh

# 3. Access Airflow UI
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow
# Then open http://localhost:8080 (admin/admin)
```

## Troubleshooting

### Minikube won't start
- Make sure Docker is running: `sudo systemctl status docker`
- Check if virtualization is enabled: `egrep -q 'vmx|svm' /proc/cpuinfo && echo "✅ Virtualization supported"`
- Try: `minikube delete -p kldp` then `minikube start -p kldp`

### Permission denied errors with Docker
- Make sure you're in the docker group: `groups | grep docker`
- Log out and back in after running: `sudo usermod -aG docker $USER`
- Or start a new shell: `newgrp docker`

### kubectl connection refused
- Make sure cluster is running: `minikube status -p kldp`
- Set kubectl context: `kubectl config use-context kldp`

## Alternative: Install Using Make (if available)

If you have `make` installed:
```bash
# Check prerequisites
make check-prereq

# After installing tools, initialize
make init-cluster
make install-airflow
```
