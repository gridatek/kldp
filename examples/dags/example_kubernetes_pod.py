"""
KLDP Example: KubernetesPodOperator Demo

This DAG demonstrates running tasks in isolated Kubernetes pods,
which is the foundation for running Spark jobs and other workloads.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from kubernetes.client import models as k8s

default_args = {
    'owner': 'kldp',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG(
    'kldp_kubernetes_example',
    default_args=default_args,
    description='Example DAG using KubernetesPodOperator',
    schedule_interval=timedelta(days=1),
    catchup=False,
    tags=['kldp', 'example', 'kubernetes'],
) as dag:

    # Task 1: Simple Python computation
    python_task = KubernetesPodOperator(
        task_id='python_computation',
        name='python-task',
        namespace='airflow',
        image='python:3.11-slim',
        cmds=['python', '-c'],
        arguments=[
            'import sys; '
            'import time; '
            'print("Starting computation..."); '
            'result = sum(range(1, 1000001)); '
            'print(f"Sum of first million numbers: {result}"); '
            'time.sleep(2); '
            'print("Task completed successfully!")'
        ],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
    )

    # Task 2: Bash commands
    bash_task = KubernetesPodOperator(
        task_id='bash_operations',
        name='bash-task',
        namespace='airflow',
        image='ubuntu:22.04',
        cmds=['/bin/bash', '-c'],
        arguments=[
            'echo "Running in Kubernetes pod..."; '
            'echo "Hostname: $(hostname)"; '
            'echo "Date: $(date)"; '
            'echo "Available memory: $(free -h)"; '
            'sleep 2; '
            'echo "Bash task completed!"'
        ],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
    )

    # Task 3: Data processing simulation
    data_processing = KubernetesPodOperator(
        task_id='data_processing',
        name='data-processing-task',
        namespace='airflow',
        image='python:3.11-slim',
        cmds=['python', '-c'],
        arguments=[
            'import json; '
            'import random; '
            'print("Simulating data processing..."); '
            'data = [{"id": i, "value": random.randint(1, 100)} for i in range(100)]; '
            'avg = sum(d["value"] for d in data) / len(data); '
            'print(f"Processed {len(data)} records"); '
            'print(f"Average value: {avg:.2f}"); '
            'print("Data processing completed!")'
        ],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        resources=k8s.V1ResourceRequirements(
            requests={'memory': '256Mi', 'cpu': '250m'},
            limits={'memory': '512Mi', 'cpu': '500m'},
        ),
    )

    # Task 4: Multi-container example with volume
    volume = k8s.V1Volume(
        name='shared-data',
        empty_dir=k8s.V1EmptyDirVolumeSource()
    )

    volume_mount = k8s.V1VolumeMount(
        name='shared-data',
        mount_path='/data',
    )

    multi_container_task = KubernetesPodOperator(
        task_id='multi_container',
        name='multi-container-task',
        namespace='airflow',
        image='python:3.11-slim',
        cmds=['python', '-c'],
        arguments=[
            'with open("/data/output.txt", "w") as f: '
            '    f.write("Hello from KLDP!\\n"); '
            'print("File written to shared volume"); '
            'with open("/data/output.txt", "r") as f: '
            '    print(f"Content: {f.read()}")'
        ],
        volumes=[volume],
        volume_mounts=[volume_mount],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
    )

    # Define task dependencies
    python_task >> bash_task >> [data_processing, multi_container_task]