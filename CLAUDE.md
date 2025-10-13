# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KLDP (Kubernetes Local Data Platform) is a batteries-included local data engineering platform running on Minikube. It provides a production-like Kubernetes environment for developing, testing, and learning data pipelines without cloud costs.

Current components:
- Apache Airflow with KubernetesExecutor
- PostgreSQL (metadata database)
- MinIO (S3-compatible object storage, planned)

Planned components: Spark Operator, Prometheus/Grafana, Kafka, JupyterHub

## Development Environment Setup

### Prerequisites
- Docker Desktop or Docker Engine
- Minikube
- kubectl
- Helm

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
- **Image**: apache/airflow:2.10.3-python3.11
- **Metadata DB**: PostgreSQL (built-in, runs in same namespace)
- **Storage**: Persistent volumes for DAGs (5Gi) and logs (10Gi)
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
- Image version (lines 10-12)
- Admin credentials (lines 15-23)
- PostgreSQL config (lines 33-50)
- Resource limits for components (lines 77-116)
- Environment variables (lines 128-138)
- Extra pip packages (lines 141-145)
- Kubernetes executor settings (lines 157-162)

When modifying Airflow configuration, update this file and run:
```bash
helm upgrade airflow apache-airflow/airflow \
    --namespace airflow \
    --values core/airflow/values.yaml
```

### scripts/init-cluster.sh
Creates minikube cluster with sensible defaults. Environment variables:
- KLDP_CPUS (default: 4)
- KLDP_MEMORY (default: 8192)
- KLDP_DISK (default: 40g)
- KLDP_K8S_VERSION (default: v1.30.0)

### scripts/install-airflow.sh
Installs Airflow using Helm chart. Environment variable:
- KLDP_AIRFLOW_VERSION (default: 1.16.0)

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

## System Requirements

**Minimal (Airflow only):**
- 4 CPU cores
- 8 GB RAM
- 20 GB disk space

**Recommended (full stack):**
- 6 CPU cores
- 12 GB RAM
- 40 GB disk space
