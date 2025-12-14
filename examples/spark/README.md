# Spark Examples

This directory contains example Spark applications for KLDP.

## Prerequisites

- Spark Operator installed: `make install-spark`
- Kubernetes cluster running: `minikube status -p kldp`

## Examples

### 1. Spark Pi (Basic Example)

Simple Spark application that calculates Pi using the Monte Carlo method.

```bash
# Submit the job
kubectl apply -f examples/spark/spark-pi.yaml

# Check status
kubectl get sparkapplications -n spark

# View logs
kubectl logs -n spark -l spark-role=driver,spark-app-name=spark-pi

# Cleanup
kubectl delete sparkapplication spark-pi -n spark
```

### 2. Spark with MinIO (S3 Integration)

Spark application configured to read/write data from MinIO object storage.

**Prerequisites:**
- MinIO installed: `make install-minio`

```bash
# Submit the job
kubectl apply -f examples/spark/spark-minio-example.yaml

# Monitor
kubectl describe sparkapplication spark-minio-example -n spark

# Cleanup
kubectl delete sparkapplication spark-minio-example -n spark
```

## Spark Application Lifecycle

1. **SUBMITTED** - Application submitted to operator
2. **RUNNING** - Driver pod is running
3. **COMPLETED** - Application finished successfully
4. **FAILED** - Application failed
5. **SUBMISSION_FAILED** - Failed to submit
6. **PENDING_RERUN** - Waiting for retry
7. **INVALIDATING** - Being invalidated
8. **SUCCEEDING** - Transitioning to completion
9. **FAILING** - Transitioning to failure

## Useful Commands

```bash
# List all Spark applications
kubectl get sparkapplications -n spark

# Describe a Spark application
kubectl describe sparkapplication <app-name> -n spark

# Get Spark application YAML
kubectl get sparkapplication <app-name> -n spark -o yaml

# View driver logs
kubectl logs -n spark -l spark-role=driver,spark-app-name=<app-name>

# View executor logs
kubectl logs -n spark -l spark-role=executor,spark-app-name=<app-name>

# Delete a Spark application
kubectl delete sparkapplication <app-name> -n spark

# Delete all Spark applications
kubectl delete sparkapplications --all -n spark
```

## Integration with Airflow

See `examples/dags/example_spark_job.py` for how to:
- Submit Spark jobs from Airflow
- Monitor job status
- Retrieve logs
- Clean up completed jobs

## Customization

To create your own Spark application:

1. Copy one of the example YAML files
2. Modify the `mainApplicationFile` to point to your application
3. Adjust `driver` and `executor` resources as needed
4. Add any required dependencies in `deps.jars`
5. Apply: `kubectl apply -f your-spark-app.yaml`

## Troubleshooting

### Pod not starting

```bash
kubectl describe pod -n spark <pod-name>
kubectl get events -n spark --sort-by='.lastTimestamp'
```

### Application stays in SUBMITTED state

Check operator logs:
```bash
kubectl logs -n spark -l app.kubernetes.io/name=spark-operator -f
```

### Out of resources

Reduce driver/executor resources in your SparkApplication YAML:
```yaml
driver:
  memory: "256m"
  cores: 1
executor:
  memory: "256m"
  cores: 1
  instances: 1
```

## Resources

- [Spark Operator Documentation](https://github.com/kubeflow/spark-operator)
- [Spark on Kubernetes Guide](https://spark.apache.org/docs/latest/running-on-kubernetes.html)
- [SparkApplication API Reference](https://github.com/kubeflow/spark-operator/blob/master/docs/api-docs.md)
