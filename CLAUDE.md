# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KLDP (Kubernetes Local Data Platform) is a batteries-included local data engineering platform running on Minikube. It provides a production-like Kubernetes environment for developing, testing, and learning data pipelines without cloud costs.

Current components:
- Apache Airflow 3.1.0 with KubernetesExecutor (Python 3.12)
- PostgreSQL (metadata database)
- MinIO (S3-compatible object storage, planned)

Planned components: Spark Operator, Prometheus/Grafana, Kafka, JupyterHub

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
4. Installs Airflow using CI-optimized configuration (core/airflow/values-ci.yaml)
5. Verifies all components are healthy
6. Tests DAG deployment and detection

**CI-Optimized Configuration (values-ci.yaml):**
The CI environment uses a separate Helm values file with:
- Reduced resource requests/limits (256Mi/512Mi RAM per component)
- Triggerer disabled to save resources (not needed for validation)
- API Server disabled (replicas: 0) to save resources (new in Airflow 3.x, not needed for validation)
- Example DAGs disabled for faster startup
- Smaller persistent volumes (1Gi DAGs, 2Gi logs)
- PostgreSQL with minimal resources (128Mi/256Mi RAM)
- Reduced parallelism settings

**Running CI checks locally:**
```bash
# Validate DAG syntax
python examples/dags/example_kubernetes_pod.py

# Run ShellCheck on scripts
shellcheck scripts/*.sh

# Validate YAML files
yamllint -d relaxed core/airflow/values.yaml
yamllint -d relaxed core/airflow/values-ci.yaml

# Test CI-optimized installation (requires clean Minikube setup)
minikube start --cpus=2 --memory=4096 --profile=kldp-ci
helm install airflow apache-airflow/airflow \
  --namespace airflow \
  --create-namespace \
  --values core/airflow/values-ci.yaml \
  --version 1.18.0 \
  --wait \
  --timeout 20m
```

**Common CI Issues:**

1. **Timeout during Helm install**: Usually caused by slow image pulls or insufficient resources
   - Solution: Images are pre-pulled in CI workflow
   - Timeout increased to 20 minutes for reliability

2. **PostgreSQL not becoming ready**: Database initialization can be slow with limited resources
   - Solution: Reduced PostgreSQL resource requirements in values-ci.yaml
   - Uses smaller persistent volume (1Gi vs 8Gi default)

3. **Out of memory errors**: CI environment has strict memory limits
   - Solution: All components configured with appropriate limits
   - Triggerer and API Server disabled to free up resources

4. **API Server not becoming ready** (Airflow 3.x): New component that may fail in resource-constrained environments
   - Solution: API Server disabled in values-ci.yaml by setting `replicas: 0`
   - Note: apiServer doesn't have an `enabled` field in the Helm chart, use `replicas: 0` instead
   - Not required for basic DAG validation and testing

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
