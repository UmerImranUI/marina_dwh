from datetime import datetime

from airflow import DAG
from airflow.providers.airbyte.operators.airbyte import AirbyteTriggerSyncOperator
from airflow.operators.bash import BashOperator


DBT_PROJECT_DIR = "/opt/airflow/dbt/marina_dwh"

with DAG(
    dag_id="marina_dbt_pipeline",
    start_date=datetime(2026, 8, 1),
    schedule=None,
    catchup=False,
) as dag:

    airbyte_sync = AirbyteTriggerSyncOperator(
        task_id="airbyte_sync",
        airbyte_conn_id="airbyte",
        connection_id="YOUR_AIRBYTE_CONNECTION_ID",
        asynchronous=False,
    )

    staging = BashOperator(
        task_id="dbt_staging",
        bash_command=f"""
            cd {DBT_PROJECT_DIR}
            dbt run --select staging
        """,
    )

    test_staging = BashOperator(
        task_id="test_staging",
        bash_command=f"""
            cd {DBT_PROJECT_DIR}
            dbt test --select staging
        """,
    )

    intermediate = BashOperator(
        task_id="dbt_intermediate",
        bash_command=f"""
            cd {DBT_PROJECT_DIR}
            dbt run --select intermediate
        """,
    )

    test_intermediate = BashOperator(
        task_id="test_intermediate",
        bash_command=f"""
            cd {DBT_PROJECT_DIR}
            dbt test --select intermediate
        """,
    )

    marts = BashOperator(
        task_id="dbt_marts",
        bash_command=f"""
            cd {DBT_PROJECT_DIR}
            dbt run --select marts
        """,
    )

    test_marts = BashOperator(
        task_id="test_marts",
        bash_command=f"""
            cd {DBT_PROJECT_DIR}
            dbt test --select marts
        """,
    )

    (
        airbyte_sync
        >> staging
        >> test_staging
        >> intermediate
        >> test_intermediate
        >> marts
        >> test_marts
    )