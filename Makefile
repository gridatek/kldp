# KLDP Makefile
# Convenience commands for managing the KLDP platform

.PHONY: help check-prereq install-dev init-cluster install-airflow install-minio install-spark start stop clean validate

help: ## Show this help message
	@echo "KLDP - Kubernetes Local Data Platform"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Environment variables:"
	@echo "  KLDP_CPUS=4              Number of CPUs for Minikube"
	@echo "  KLDP_MEMORY=8192         Memory in MB for Minikube"
	@echo "  KLDP_DISK=40g            Disk size for Minikube"
	@echo "  KLDP_K8S_VERSION=v1.30.0 Kubernetes version"

check-prereq: ## Check if all prerequisites are installed
	@./scripts/check-prerequisites.sh

install-dev: ## Install Python development dependencies for local DAG testing
	@echo "Installing Python development dependencies..."
	pip install -r requirements-dev.txt --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-3.1.0/constraints-3.12.txt"
	@echo "✅ Development dependencies installed"

init-cluster: ## Initialize Minikube cluster
	@./scripts/init-cluster.sh

install-airflow: ## Install Airflow on the cluster
	@./scripts/install-airflow.sh

install-minio: ## Install MinIO object storage on the cluster
	@./scripts/install-minio.sh

install-spark: ## Install Spark Operator on the cluster
	@./scripts/install-spark.sh

start: ## Start the KLDP cluster
	@echo "Starting KLDP cluster..."
	minikube start -p kldp
	@echo "✅ Cluster started"

stop: ## Stop the KLDP cluster (preserves data)
	@echo "Stopping KLDP cluster..."
	minikube stop -p kldp
	@echo "✅ Cluster stopped"

clean: ## Delete the KLDP cluster (WARNING: destroys all data)
	@echo "⚠️  This will delete the entire KLDP cluster and all data!"
	@read -p "Are you sure? [y/N]: " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		minikube delete -p kldp; \
		echo "✅ Cluster deleted"; \
	else \
		echo "Cancelled"; \
	fi

validate: ## Validate DAG syntax and YAML files
	@echo "Validating DAG files..."
	@for dag in examples/dags/*.py; do \
		echo "  Checking $$dag..."; \
		python3 "$$dag" || exit 1; \
	done
	@echo "Validating YAML files..."
	@python3 -c "import yaml; yaml.safe_load(open('core/airflow/values.yaml')); print('  ✅ values.yaml')"
	@python3 -c "import yaml; yaml.safe_load(open('core/airflow/values-ci-emptydir.yaml')); print('  ✅ values-ci-emptydir.yaml')"
	@echo "✅ All validations passed"

dashboard: ## Open Kubernetes dashboard
	@echo "Opening Kubernetes dashboard..."
	minikube dashboard -p kldp

airflow-ui: ## Open Airflow UI
	@echo "Opening Airflow UI..."
	@echo "Default credentials: admin/admin"
	minikube service airflow-webserver -n airflow

minio-console: ## Port forward MinIO console
	@echo "Port forwarding MinIO console..."
	@echo "Console will be available at: http://localhost:9001"
	@echo "Credentials: minioadmin/minioadmin"
	kubectl port-forward svc/minio 9001:9001 -n storage

minio-api: ## Port forward MinIO S3 API
	@echo "Port forwarding MinIO S3 API..."
	@echo "API will be available at: http://localhost:9000"
	kubectl port-forward svc/minio 9000:9000 -n storage

logs-scheduler: ## Show Airflow scheduler logs
	kubectl logs -n airflow -l component=scheduler -f

logs-webserver: ## Show Airflow webserver logs
	kubectl logs -n airflow -l component=webserver -f

logs-minio: ## Show MinIO logs
	kubectl logs -n storage -l app.kubernetes.io/name=minio -f

logs-spark: ## Show Spark Operator logs
	kubectl logs -n spark -l app.kubernetes.io/name=spark-operator -f

spark-apps: ## List Spark applications
	@kubectl get sparkapplications -n spark

status: ## Show cluster and component status
	@echo "=== Cluster Status ==="
	@minikube status -p kldp || echo "Cluster not running"
	@echo ""
	@echo "=== Airflow Pods ==="
	@kubectl get pods -n airflow || echo "Airflow not installed"
	@echo ""
	@echo "=== Airflow Release ==="
	@helm status airflow -n airflow 2>/dev/null || echo "Airflow not installed"
	@echo ""
	@echo "=== MinIO Pods ==="
	@kubectl get pods -n storage || echo "MinIO not installed"
	@echo ""
	@echo "=== MinIO Release ==="
	@helm status minio -n storage 2>/dev/null || echo "MinIO not installed"
	@echo ""
	@echo "=== Spark Operator Pods ==="
	@kubectl get pods -n spark || echo "Spark Operator not installed"
	@echo ""
	@echo "=== Spark Operator Release ==="
	@helm status spark-operator -n spark 2>/dev/null || echo "Spark Operator not installed"
	@echo ""
	@echo "=== Spark Applications ==="
	@kubectl get sparkapplications -n spark 2>/dev/null || echo "No Spark applications running"
