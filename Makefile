# KLDP Makefile
# Convenience commands for managing the KLDP platform

.PHONY: help check-prereq install-dev init-cluster install-airflow start stop clean validate

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

logs-scheduler: ## Show Airflow scheduler logs
	kubectl logs -n airflow -l component=scheduler -f

logs-webserver: ## Show Airflow webserver logs
	kubectl logs -n airflow -l component=webserver -f

status: ## Show cluster and Airflow status
	@echo "=== Cluster Status ==="
	@minikube status -p kldp || echo "Cluster not running"
	@echo ""
	@echo "=== Airflow Pods ==="
	@kubectl get pods -n airflow || echo "Airflow not installed"
	@echo ""
	@echo "=== Airflow Release ==="
	@helm status airflow -n airflow 2>/dev/null || echo "Airflow not installed"
