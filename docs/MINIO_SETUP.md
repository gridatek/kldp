# MinIO Setup Guide

MinIO provides S3-compatible object storage for the KLDP data lake. This guide covers installation, configuration, and usage.

## Quick Start

```bash
# Install MinIO
make install-minio

# Or directly:
./scripts/install-minio.sh

# Access MinIO Console
make minio-console
# Then open http://localhost:9001 (minioadmin/minioadmin)
```

## What is MinIO?

MinIO is a high-performance, S3-compatible object storage system. In KLDP, it provides:

- **S3-Compatible Storage**: Use standard S3 SDKs (boto3, AWS CLI, etc.)
- **Data Lake Foundation**: Store raw, processed, and curated data
- **Multi-Bucket Support**: Organize data by purpose or environment
- **Web Console**: Visual interface for managing data
- **Kubernetes Native**: Runs efficiently in local Minikube cluster

## Architecture

MinIO is deployed in the `storage` namespace with:

- **Mode**: Standalone (single-server for local development)
- **Persistence**: 10Gi persistent volume (default storage class)
- **Resources**: 256Mi/512Mi memory, 100m/500m CPU
- **Services**:
  - API (S3): Port 9000
  - Console (Web UI): Port 9001

## Installation

### Prerequisites

- KLDP cluster initialized (`make init-cluster`)
- Helm 3.x installed

### Install MinIO

```bash
# Using Makefile
make install-minio

# Or directly
./scripts/install-minio.sh

# Custom MinIO version (optional)
KLDP_MINIO_VERSION=14.7.17 ./scripts/install-minio.sh
```

### Verify Installation

```bash
# Check MinIO pod status
kubectl get pods -n storage

# Check MinIO service
kubectl get svc -n storage

# View MinIO logs
make logs-minio
```

## Accessing MinIO

### MinIO Console (Web UI)

Access the web interface for visual management:

```bash
# Option 1: Using Makefile
make minio-console

# Option 2: Direct port forward
kubectl port-forward svc/minio 9001:9001 -n storage
```

Then open http://localhost:9001 and login with:
- **Username**: minioadmin
- **Password**: minioadmin

### S3 API Endpoint

For programmatic access (boto3, AWS CLI, etc.):

```bash
# Port forward S3 API
make minio-api

# Or directly
kubectl port-forward svc/minio 9000:9000 -n storage
```

API endpoint: http://localhost:9000

## Default Buckets

MinIO is configured with four default buckets:

1. **`datalake`** - General purpose data lake storage
2. **`raw`** - Landing zone for raw/ingested data
3. **`processed`** - Transformed and cleaned data
4. **`curated`** - Business-ready, analytics-optimized data

## Using MinIO from Airflow

### Example DAG

See `examples/dags/example_minio_s3.py` for a complete example showing:
- Connection setup
- Uploading data
- Listing objects
- Downloading and processing files

### Connection Configuration

From within the Kubernetes cluster (Airflow tasks):

```python
import boto3
from botocore.client import Config

s3_client = boto3.client(
    's3',
    endpoint_url='http://minio.storage.svc.cluster.local:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# List buckets
response = s3_client.list_buckets()
for bucket in response['Buckets']:
    print(f"Bucket: {bucket['Name']}")
```

### Using AWS CLI

```bash
# Configure AWS CLI for MinIO
kubectl port-forward svc/minio 9000:9000 -n storage &

aws configure set aws_access_key_id minioadmin
aws configure set aws_secret_access_key minioadmin
aws configure set region us-east-1

# Use with --endpoint-url flag
aws s3 ls --endpoint-url http://localhost:9000
aws s3 cp file.txt s3://datalake/ --endpoint-url http://localhost:9000
```

## Data Lake Pattern

Recommended multi-bucket data lake architecture:

```
┌─────────────┐
│   Sources   │
│ (APIs, DBs) │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ raw/        │  ← Landing zone (immutable)
│  - json/    │
│  - csv/     │
│  - parquet/ │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ processed/  │  ← Cleaned & transformed
│  - bronze/  │
│  - silver/  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ curated/    │  ← Analytics-ready
│  - gold/    │
│  - reports/ │
└─────────────┘
```

### Example Workflow

```python
# 1. Ingest raw data
s3_client.put_object(
    Bucket='raw',
    Key='sales/2025/01/data.json',
    Body=raw_data
)

# 2. Transform and store processed
s3_client.put_object(
    Bucket='processed',
    Key='sales/silver/2025-01-sales.parquet',
    Body=processed_data
)

# 3. Create analytics-ready curated data
s3_client.put_object(
    Bucket='curated',
    Key='sales/gold/monthly-summary.parquet',
    Body=aggregated_data
)
```

## Configuration

MinIO configuration is in `core/storage/minio-values.yaml`. Key settings:

### Resources

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Persistence

```yaml
persistence:
  enabled: true
  size: 10Gi
  storageClass: ""  # Uses default
```

### Authentication

```yaml
auth:
  rootUser: minioadmin
  rootPassword: minioadmin
```

**Note**: Change credentials for production use!

### Modify Configuration

```bash
# Edit values file
vim core/storage/minio-values.yaml

# Upgrade MinIO release
helm upgrade minio bitnami/minio \
    --namespace storage \
    --values core/storage/minio-values.yaml
```

## Common Operations

### Create a New Bucket

```python
s3_client.create_bucket(Bucket='my-new-bucket')
```

Or via Console: Buckets → Create Bucket

### Upload File

```python
with open('data.csv', 'rb') as f:
    s3_client.upload_fileobj(f, 'datalake', 'datasets/data.csv')
```

### Download File

```python
s3_client.download_file('datalake', 'datasets/data.csv', 'local-data.csv')
```

### List Objects

```python
response = s3_client.list_objects_v2(
    Bucket='datalake',
    Prefix='datasets/'
)
for obj in response.get('Contents', []):
    print(f"{obj['Key']} - {obj['Size']} bytes")
```

### Delete Object

```python
s3_client.delete_object(Bucket='datalake', Key='datasets/old-file.csv')
```

## Monitoring

### Check Status

```bash
# Pod status
kubectl get pods -n storage

# Service endpoints
kubectl get svc -n storage

# Persistent volume claim
kubectl get pvc -n storage
```

### View Logs

```bash
# Real-time logs
make logs-minio

# Last 100 lines
kubectl logs -n storage -l app.kubernetes.io/name=minio --tail=100
```

### Resource Usage

```bash
# Pod resource usage
kubectl top pod -n storage
```

## Troubleshooting

### Pod Not Starting

```bash
# Check pod events
kubectl describe pod -n storage -l app.kubernetes.io/name=minio

# Check PVC status
kubectl get pvc -n storage
```

### Connection Refused

- Ensure port forwarding is active
- Check if MinIO pod is running
- Verify service is exposed correctly

### Authentication Failed

- Verify credentials (minioadmin/minioadmin by default)
- Check `auth` section in `core/storage/minio-values.yaml`

### Out of Space

```bash
# Check PVC size
kubectl get pvc -n storage

# Resize PVC (if storage class supports it)
kubectl patch pvc minio -n storage -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

## Integration with Other Components

### With Airflow

Use KubernetesPodOperator with boto3 (see `example_minio_s3.py`)

### With Spark (Future)

```python
# Spark with MinIO
spark.read \
    .option("fs.s3a.endpoint", "http://minio.storage.svc.cluster.local:9000") \
    .option("fs.s3a.access.key", "minioadmin") \
    .option("fs.s3a.secret.key", "minioadmin") \
    .parquet("s3a://datalake/data/")
```

### With Pandas

```python
import pandas as pd
import s3fs

# Create S3 filesystem
fs = s3fs.S3FileSystem(
    client_kwargs={
        'endpoint_url': 'http://minio.storage.svc.cluster.local:9000'
    },
    key='minioadmin',
    secret='minioadmin'
)

# Read Parquet from MinIO
df = pd.read_parquet('s3://datalake/data.parquet', filesystem=fs)
```

## Security Best Practices

For production deployments:

1. **Change Default Credentials**
   ```yaml
   auth:
     rootUser: admin
     rootPassword: <strong-password>
   ```

2. **Use Kubernetes Secrets**
   ```bash
   kubectl create secret generic minio-credentials \
       --from-literal=root-user=admin \
       --from-literal=root-password=<password> \
       -n storage
   ```

3. **Create IAM Policies**
   - Limit bucket access per application
   - Use read-only policies for analytics

4. **Enable TLS**
   - Use cert-manager for certificates
   - Configure HTTPS endpoints

## Uninstalling MinIO

```bash
# Delete MinIO release
helm uninstall minio -n storage

# Delete PVC (optional, destroys data)
kubectl delete pvc -n storage -l app.kubernetes.io/name=minio
```

## Additional Resources

- [MinIO Official Documentation](https://min.io/docs/)
- [Bitnami MinIO Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/minio)
- [AWS S3 boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html)
- [Example DAG](../examples/dags/example_minio_s3.py)

## Next Steps

After setting up MinIO:

1. **Run the example DAG**: `examples/dags/example_minio_s3.py`
2. **Create custom buckets** for your use case
3. **Integrate with Spark** for large-scale data processing (coming soon)
4. **Set up data retention policies** in MinIO Console
5. **Configure bucket notifications** for event-driven workflows
