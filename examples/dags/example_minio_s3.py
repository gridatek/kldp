"""
Example DAG demonstrating MinIO S3 operations with Airflow

This DAG shows how to:
1. Connect to MinIO (S3-compatible storage)
2. Create and list buckets
3. Upload and download objects
4. Process data stored in MinIO

Prerequisites:
- MinIO installed in the 'storage' namespace
- boto3 library available in Airflow
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from kubernetes.client import models as k8s

# Default arguments for the DAG
default_args = {
    'owner': 'kldp',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

# MinIO connection details (using Kubernetes service DNS)
MINIO_ENDPOINT = "minio.storage.svc.cluster.local:9000"
MINIO_ACCESS_KEY = "minioadmin"
MINIO_SECRET_KEY = "minioadmin"
MINIO_BUCKET = "datalake"

# Define the DAG
with DAG(
    'example_minio_s3_operations',
    default_args=default_args,
    description='Example DAG showing MinIO S3 operations',
    schedule_interval=None,  # Manual trigger only
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['example', 'minio', 's3', 'storage'],
) as dag:

    # Task 1: Test MinIO connectivity and list buckets
    test_connection = KubernetesPodOperator(
        task_id='test_minio_connection',
        name='test-minio-connection',
        namespace='airflow',
        image='python:3.12-slim',
        cmds=['python', '-c'],
        arguments=['''
import boto3
from botocore.client import Config

print("🔗 Testing MinIO connection...")

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url='http://''' + MINIO_ENDPOINT + '''',
    aws_access_key_id='''' + MINIO_ACCESS_KEY + '''',
    aws_secret_access_key='''' + MINIO_SECRET_KEY + '''',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# List buckets
print("📦 Available buckets:")
response = s3_client.list_buckets()
for bucket in response['Buckets']:
    print(f"  - {bucket['Name']}")

print("✅ MinIO connection successful!")
        '''],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        env_vars=[
            k8s.V1EnvVar(name='PYTHONUNBUFFERED', value='1'),
        ],
    )

    # Task 2: Upload sample data to MinIO
    upload_data = KubernetesPodOperator(
        task_id='upload_sample_data',
        name='upload-sample-data',
        namespace='airflow',
        image='python:3.12-slim',
        cmds=['python', '-c'],
        arguments=['''
import boto3
from botocore.client import Config
from datetime import datetime
import json

print("📤 Uploading sample data to MinIO...")

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url='http://''' + MINIO_ENDPOINT + '''',
    aws_access_key_id='''' + MINIO_ACCESS_KEY + '''',
    aws_secret_access_key='''' + MINIO_SECRET_KEY + '''',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# Create sample data
sample_data = {
    "timestamp": datetime.now().isoformat(),
    "message": "Hello from KLDP!",
    "data": {
        "temperature": 23.5,
        "humidity": 65.2,
        "location": "datacenter-01"
    }
}

# Upload to MinIO
key = f"samples/data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
s3_client.put_object(
    Bucket='''' + MINIO_BUCKET + '''',
    Key=key,
    Body=json.dumps(sample_data, indent=2),
    ContentType='application/json'
)

print(f"✅ Uploaded: s3://''' + MINIO_BUCKET + '''/{key}")
print(f"📊 Data: {json.dumps(sample_data, indent=2)}")
        '''],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        env_vars=[
            k8s.V1EnvVar(name='PYTHONUNBUFFERED', value='1'),
        ],
    )

    # Task 3: List objects in bucket
    list_objects = KubernetesPodOperator(
        task_id='list_bucket_objects',
        name='list-bucket-objects',
        namespace='airflow',
        image='python:3.12-slim',
        cmds=['python', '-c'],
        arguments=['''
import boto3
from botocore.client import Config

print("📋 Listing objects in MinIO bucket...")

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url='http://''' + MINIO_ENDPOINT + '''',
    aws_access_key_id='''' + MINIO_ACCESS_KEY + '''',
    aws_secret_access_key='''' + MINIO_SECRET_KEY + '''',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# List objects
print(f"📦 Objects in bucket '''' + MINIO_BUCKET + '''':")
response = s3_client.list_objects_v2(Bucket='''' + MINIO_BUCKET + '''')

if 'Contents' in response:
    for obj in response['Contents']:
        size_kb = obj['Size'] / 1024
        print(f"  - {obj['Key']} ({size_kb:.2f} KB) - {obj['LastModified']}")
    print(f"\\n✅ Total objects: {len(response['Contents'])}")
else:
    print("  (empty)")
        '''],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        env_vars=[
            k8s.V1EnvVar(name='PYTHONUNBUFFERED', value='1'),
        ],
    )

    # Task 4: Download and process data
    process_data = KubernetesPodOperator(
        task_id='download_and_process',
        name='download-and-process',
        namespace='airflow',
        image='python:3.12-slim',
        cmds=['python', '-c'],
        arguments=['''
import boto3
from botocore.client import Config
import json

print("📥 Downloading and processing data from MinIO...")

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url='http://''' + MINIO_ENDPOINT + '''',
    aws_access_key_id='''' + MINIO_ACCESS_KEY + '''',
    aws_secret_access_key='''' + MINIO_SECRET_KEY + '''',
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

# List and process sample files
response = s3_client.list_objects_v2(
    Bucket='''' + MINIO_BUCKET + '''',
    Prefix='samples/'
)

if 'Contents' in response:
    print(f"📊 Processing {len(response['Contents'])} files...")

    for obj in response['Contents']:
        # Download object
        obj_response = s3_client.get_object(
            Bucket='''' + MINIO_BUCKET + '''',
            Key=obj['Key']
        )

        # Read and parse JSON
        data = json.loads(obj_response['Body'].read())

        print(f"\\n  File: {obj['Key']}")
        print(f"  Timestamp: {data.get('timestamp', 'N/A')}")
        print(f"  Message: {data.get('message', 'N/A')}")

        if 'data' in data:
            print(f"  Metrics:")
            for key, value in data['data'].items():
                print(f"    - {key}: {value}")

    print(f"\\n✅ Successfully processed {len(response['Contents'])} files")
else:
    print("⚠️  No files found in samples/ prefix")
        '''],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        env_vars=[
            k8s.V1EnvVar(name='PYTHONUNBUFFERED', value='1'),
        ],
    )

    # Define task dependencies
    test_connection >> upload_data >> list_objects >> process_data


# This allows the DAG to be tested locally
if __name__ == "__main__":
    print("✅ DAG validation successful!")
    print(f"DAG ID: {dag.dag_id}")
    print(f"Tasks: {[task.task_id for task in dag.tasks]}")
