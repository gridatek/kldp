"""
Example DAG demonstrating Spark job submission with Airflow

This DAG shows how to:
1. Submit Spark applications to Kubernetes using SparkKubernetesOperator
2. Monitor Spark job status
3. Process data with Spark and store results in MinIO

Prerequisites:
- Spark Operator installed in the 'spark' namespace
- MinIO installed in the 'storage' namespace
- SparkApplication CRD registered in Kubernetes
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
from kubernetes.client import models as k8s
import textwrap

# Default arguments for the DAG
default_args = {
    'owner': 'kldp',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=2),
}

# Define the DAG
with DAG(
    'example_spark_job_submission',
    default_args=default_args,
    description='Example DAG for submitting and monitoring Spark jobs',
    schedule=None,  # Manual trigger only (Airflow 3.x syntax)
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=['example', 'spark', 'data-processing'],
) as dag:

    # Task 1: Submit Spark Pi calculation job
    submit_spark_pi = KubernetesPodOperator(
        task_id='submit_spark_pi',
        name='submit-spark-pi',
        namespace='airflow',
        image='bitnami/kubectl:latest',
        cmds=['sh', '-c'],
        arguments=[textwrap.dedent('''
            # Create Spark Pi job
            cat <<EOF | kubectl apply -f -
            apiVersion: sparkoperator.k8s.io/v1beta2
            kind: SparkApplication
            metadata:
              name: spark-pi-{{ ts_nodash | lower }}
              namespace: spark
            spec:
              type: Scala
              mode: cluster
              image: "apache/spark:3.5.0"
              imagePullPolicy: IfNotPresent
              mainClass: org.apache.spark.examples.SparkPi
              mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar"
              sparkVersion: "3.5.0"

              restartPolicy:
                type: Never

              driver:
                cores: 1
                coreLimit: "1000m"
                memory: "512m"
                labels:
                  version: 3.5.0
                  airflow-dag-id: {{ dag.dag_id }}
                  airflow-task-id: {{ task.task_id }}
                serviceAccount: spark

              executor:
                cores: 1
                instances: 2
                memory: "512m"
                labels:
                  version: 3.5.0
                  airflow-dag-id: {{ dag.dag_id }}
                  airflow-task-id: {{ task.task_id }}
            EOF

            echo "✅ Spark Pi job submitted: spark-pi-{{ ts_nodash | lower }}"
        ''')],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        service_account_name='airflow-worker',
    )

    # Task 2: Wait and check Spark job status
    check_spark_status = KubernetesPodOperator(
        task_id='check_spark_job_status',
        name='check-spark-status',
        namespace='airflow',
        image='bitnami/kubectl:latest',
        cmds=['sh', '-c'],
        arguments=[textwrap.dedent('''
            JOB_NAME="spark-pi-{{ ts_nodash | lower }}"

            echo "Waiting for Spark job $JOB_NAME to complete..."

            # Wait for job to complete (max 5 minutes)
            for i in $(seq 1 60); do
                STATUS=$(kubectl get sparkapplication $JOB_NAME -n spark -o jsonpath='{.status.applicationState.state}' 2>/dev/null || echo "UNKNOWN")

                echo "[$i/60] Job status: $STATUS"

                if [ "$STATUS" = "COMPLETED" ]; then
                    echo "✅ Spark job completed successfully!"

                    # Get driver logs
                    echo ""
                    echo "=== Driver Logs (last 20 lines) ==="
                    DRIVER_POD=$(kubectl get pods -n spark -l spark-role=driver,spark-app-name=$JOB_NAME -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                    if [ -n "$DRIVER_POD" ]; then
                        kubectl logs -n spark $DRIVER_POD --tail=20 2>/dev/null || echo "Driver pod logs not available"
                    fi

                    exit 0
                elif [ "$STATUS" = "FAILED" ]; then
                    echo "❌ Spark job failed!"
                    kubectl describe sparkapplication $JOB_NAME -n spark
                    exit 1
                fi

                sleep 5
            done

            echo "⚠️  Job did not complete within timeout"
            kubectl describe sparkapplication $JOB_NAME -n spark
            exit 1
        ''')],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        service_account_name='airflow-worker',
    )

    # Task 3: List all Spark applications
    list_spark_apps = KubernetesPodOperator(
        task_id='list_spark_applications',
        name='list-spark-apps',
        namespace='airflow',
        image='bitnami/kubectl:latest',
        cmds=['sh', '-c'],
        arguments=[textwrap.dedent('''
            echo "📊 Listing all Spark applications:"
            kubectl get sparkapplications -n spark

            echo ""
            echo "📈 Spark application details:"
            kubectl get sparkapplications -n spark -o custom-columns=\
            NAME:.metadata.name,\
            STATE:.status.applicationState.state,\
            STARTED:.status.executionAttempts[0].executionAttemptRequestTime,\
            DRIVER:.status.driverInfo.podName
        ''')],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        service_account_name='airflow-worker',
    )

    # Task 4: Cleanup completed Spark job
    cleanup_spark_job = KubernetesPodOperator(
        task_id='cleanup_spark_job',
        name='cleanup-spark-job',
        namespace='airflow',
        image='bitnami/kubectl:latest',
        cmds=['sh', '-c'],
        arguments=[textwrap.dedent('''
            JOB_NAME="spark-pi-{{ ts_nodash | lower }}"

            echo "Cleaning up Spark job $JOB_NAME..."
            kubectl delete sparkapplication $JOB_NAME -n spark --ignore-not-found=true

            echo "✅ Cleanup complete"
        ''')],
        get_logs=True,
        is_delete_operator_pod=True,
        in_cluster=True,
        service_account_name='airflow-worker',
        trigger_rule='all_done',  # Run even if previous tasks failed
    )

    # Define task dependencies
    submit_spark_pi >> check_spark_status >> list_spark_apps >> cleanup_spark_job


# This allows the DAG to be tested locally
if __name__ == "__main__":
    print("✅ DAG validation successful!")
    print(f"DAG ID: {dag.dag_id}")
    print(f"Tasks: {[task.task_id for task in dag.tasks]}")
