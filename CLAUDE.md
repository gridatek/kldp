# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KLDP (Kubernetes Local Data Platform) is a batteries-included local data engineering platform running on Minikube. It provides a production-like Kubernetes environment for developing, testing, and learning data pipelines without cloud costs.

Current components:
- Apache Airflow 3.1.0 with KubernetesExecutor (Python 3.12)
- PostgreSQL (metadata database)
- MinIO (S3-compatible object storage)
- Spark Operator (for running Spark jobs on Kubernetes)
- Prometheus/Grafana (monitoring and observability stack)

Planned components: Kafka, JupyterHub

## Development Environment Setup

### Prerequisites
- Docker Desktop or Docker Engine
- Minikube
- kubectl
- Helm

**Windows Users**: These scripts are bash scripts. On Windows, use Git Bash, WSL2 (recommended), or create PowerShell equivalents.

### Initialize Cluster
```bash
# Set resource limits via environment variables (optional)
export KLDP_CPUS=4
export KLDP_MEMORY=8192
export KLDP_DISK=40g
export KLDP_K8S_VERSION=v1.30.0

# Initialize minikube cluster named "kldp"
./scripts/init-cluster.sh
```

This creates namespaces: airflow, spark, storage, monitoring

### Install Airflow
```bash
# From repository root
./scripts/install-airflow.sh

# Or from scripts directory
cd scripts
./install-airflow.sh
```

Default credentials: admin/admin

### Access Airflow UI
```bash
# Option 1: Port forward
kubectl port-forward svc/airflow-webserver 8080:8080 -n airflow

# Option 2: Minikube service
minikube service airflow-webserver -n airflow
```

### Install MinIO
```bash
# From repository root
./scripts/install-minio.sh

# Or using Makefile
make install-minio
```

Default credentials: minioadmin/minioadmin

### Access MinIO Console
```bash
# Console UI (Web Interface)
kubectl port-forward svc/minio 9001:9001 -n storage
# Then open http://localhost:9001

# S3 API Endpoint
kubectl port-forward svc/minio 9000:9000 -n storage

# Or using Makefile
make minio-console  # Console UI
make minio-api      # S3 API
```

See [MinIO Setup Guide](docs/MINIO_SETUP.md) for detailed documentation.

## Common Commands

### Cluster Management
```bash
# Check cluster status
minikube status -p kldp
kubectl cluster-info

# Access Kubernetes dashboard
minikube dashboard -p kldp

# Stop cluster (preserve data)
minikube stop -p kldp

# Delete cluster
minikube delete -p kldp
```

### Airflow Operations
```bash
# View pods
kubectl get pods -n airflow

# View logs
kubectl logs -n airflow -l component=scheduler -f
kubectl logs -n airflow -l component=webserver -f

# Restart components
kubectl rollout restart deployment airflow-scheduler -n airflow
kubectl rollout restart deployment airflow-webserver -n airflow

# Check Airflow release status
helm status airflow -n airflow
```

### DAG Development
```bash
# Test DAG syntax locally
python examples/dags/my_dag.py

# Copy DAG to Airflow (simple method)
kubectl cp examples/dags/my_dag.py airflow/airflow-scheduler-0:/opt/airflow/dags/

# View task logs
kubectl logs -n airflow <pod-name> -f
```

## Architecture

### Airflow Configuration
- **Executor**: KubernetesExecutor (tasks run in isolated pods)
- **Image**: apache/airflow:3.1.0-python3.12
- **Metadata DB**: PostgreSQL (built-in, runs in same namespace)
- **Storage**: Persistent volumes for DAGs (5Gi, ReadWriteOnce) and logs (10Gi)
  - Note: ReadWriteOnce is sufficient for Minikube's standard storage class
  - Only scheduler needs DAG volume access with KubernetesExecutor
  - Task pods receive DAG code through Airflow's serialization mechanism, not via shared volume
- **Resource Limits**: Configured for local development in core/airflow/values.yaml

### Kubernetes Namespaces
- `airflow`: Airflow components and task pods
- `spark`: Spark operator and applications (future)
- `storage`: MinIO and shared storage (future)
- `monitoring`: Prometheus and Grafana (future)

### DAG Execution Flow
1. Scheduler reads DAGs from persistent volume
2. KubernetesExecutor creates a new pod for each task
3. Task pod runs in the `airflow` namespace
4. Pod is automatically deleted after completion (configurable)
5. Logs persisted to shared volume

### Example DAG Pattern
The project uses KubernetesPodOperator for running tasks in isolated containers. See examples/dags/example_kubernetes_pod.py:131 for patterns including:
- Python computations in pods
- Bash commands in Ubuntu containers
- Data processing simulations
- Multi-container tasks with shared volumes
- Resource limits specification

## Key Configuration Files

### core/airflow/values.yaml
Helm values for Airflow deployment. Key settings:
- Executor type (line 5: KubernetesExecutor)
- Image version (lines 10-12: apache/airflow:3.1.0-python3.12)
- Admin credentials (lines 24-31)
- PostgreSQL config (lines 40-57)
- Resource limits for components (lines 84-113)
- Environment variables (lines 125-135, note: uses api section for Airflow 3.x)
- Extra pip packages (lines 138-142)
- Kubernetes executor settings (lines 153-158)

When modifying Airflow configuration, update this file and run:
```bash
helm upgrade airflow apache-airflow/airflow \
    --namespace airflow \
    --values core/airflow/values.yaml
```

**Note**: Configuration changes in values.yaml require `helm upgrade`. For DAG changes only, no helm upgrade is needed - just restart the scheduler if DAGs aren't being picked up automatically.

### scripts/init-cluster.sh
Creates minikube cluster with sensible defaults. Environment variables:
- KLDP_CPUS (default: 4)
- KLDP_MEMORY (default: 8192)
- KLDP_DISK (default: 40g)
- KLDP_K8S_VERSION (default: v1.30.0)

### scripts/install-airflow.sh
Installs Airflow using Helm chart. Environment variable:
- KLDP_AIRFLOW_VERSION (default: 1.18.0)

## Quick Diagnostics

```bash
# Check overall cluster health
kubectl get pods -n airflow
kubectl get pvc -n airflow
helm status airflow -n airflow

# Check Airflow configuration
kubectl exec -n airflow deployment/airflow-scheduler -- airflow config list

# Access scheduler pod for manual DAG inspection
kubectl exec -it -n airflow deployment/airflow-scheduler -- /bin/bash

# View all resources and events
kubectl get all -n airflow
kubectl get events -n airflow --sort-by='.lastTimestamp'

# Test DAG syntax locally (before deployment)
python examples/dags/my_dag.py

# Validate shell scripts with ShellCheck
shellcheck scripts/*.sh

# Validate YAML syntax
yamllint -d relaxed core/airflow/values.yaml
```

## Troubleshooting

### Pods Pending or Not Starting
```bash
# Check events
kubectl get events -n airflow --sort-by='.lastTimestamp'

# Describe pod for details
kubectl describe pod <pod-name> -n airflow
```

Common causes:
- Insufficient resources: Adjust KLDP_CPUS/KLDP_MEMORY
- Storage issues: Check storage class availability
- Image pull issues: Verify internet connection

### DAGs Not Appearing
1. Verify DAG syntax: `python examples/dags/my_dag.py`
2. Check scheduler logs: `kubectl logs -n airflow -l component=scheduler -f`
3. Ensure DAG is in correct location
4. Wait ~30 seconds for scheduler to detect changes

### Tasks Failing
1. Check task logs in Airflow UI
2. Verify pod creation: `kubectl get pods -n airflow -l airflow-worker`
3. Check resource constraints: `kubectl describe pod <pod-name> -n airflow`

## Project Structure

```
kldp/
├── core/
│   ├── airflow/          # Airflow Helm configurations
│   ├── compute/          # Spark operator configs (planned)
│   ├── storage/          # MinIO, PostgreSQL configs
│   └── monitoring/       # Observability stack (planned)
├── scripts/
│   ├── init-cluster.sh   # Initialize minikube cluster
│   ├── install-airflow.sh # Install Airflow
│   ├── install-spark.sh  # Install Spark (planned)
│   └── install-all.sh    # Full stack installation (planned)
├── examples/
│   └── dags/             # Sample Airflow DAGs
└── docs/                 # Documentation
```

## Development Workflow

1. Make changes to configuration files or DAGs
2. For Airflow config changes:
   - Update core/airflow/values.yaml
   - Run `helm upgrade` command
3. For DAG changes:
   - Edit files in examples/dags/
   - Copy to Airflow using kubectl cp
   - Or configure persistent volume mount (see docs/GETTING_STARTED.md)
4. Test in Airflow UI
5. Commit changes when working

## CI/CD

The project includes a GitHub Actions workflow (.github/workflows/ci.yml) that validates:
- DAG syntax (Python 3.12)
- Full KLDP setup on Minikube
- Shell script quality (ShellCheck)
- YAML syntax and Helm values

The CI workflow:
1. Validates all DAG files can be parsed by Airflow 3.1.0
2. Spins up Minikube with reduced resources (2 CPUs, 4GB RAM)
3. Pre-pulls Docker images to avoid timeout issues
4. Installs all components using the SAME scripts and values files as local development
5. Verifies all components are healthy
6. Tests DAG deployment and detection

**Single Source of Truth:**
CI uses the exact same installation scripts and values files as local development:
- `./scripts/install-airflow.sh` with `core/airflow/values.yaml`
- `./scripts/install-minio.sh` with `core/storage/minio-values.yaml`
- `./scripts/install-spark.sh` with `core/compute/spark-operator-values.yaml`
- `./scripts/install-monitoring.sh` with `core/monitoring/prometheus-grafana-values.yaml`

This ensures:
- CI validates the real configuration users run locally
- If it works locally, it works in CI
- No configuration drift between environments
- Easier debugging: test locally with same setup as CI

**Running CI checks locally:**
```bash
# Validate DAG syntax
python examples/dags/example_kubernetes_pod.py

# Run ShellCheck on scripts
shellcheck scripts/*.sh

# Validate YAML files
yamllint -d relaxed core/airflow/values.yaml
yamllint -d relaxed core/storage/minio-values.yaml

# Test full installation locally (same as CI)
./scripts/init-cluster.sh
./scripts/install-airflow.sh
./scripts/install-minio.sh
./scripts/install-spark.sh
./scripts/install-monitoring.sh
```

**Common CI Issues:**

1. **Timeout during Helm install**: Usually caused by slow image pulls
   - Solution: Images are pre-pulled in CI workflow before Helm install
   - Generous timeouts configured (30-35 minutes for Airflow)

2. **PersistentVolumeClaim provisioning**: Storage provisioning can take time in CI
   - Solution: Standard Minikube storage class is used, usually provisions quickly
   - If issues occur locally, check: `kubectl get pvc -n <namespace>`

## System Requirements

**Minimal (Airflow only):**
- 4 CPU cores
- 8 GB RAM
- 20 GB disk space

**Recommended (full stack):**
- 6 CPU cores
- 12 GB RAM
- 40 GB disk space

**CI Environment (GitHub Actions):**
- 2 CPU cores
- 4 GB RAM
- Uses ubuntu-latest runners
