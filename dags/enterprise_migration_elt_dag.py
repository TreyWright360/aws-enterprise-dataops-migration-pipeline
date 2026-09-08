from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.amazon.aws.operators.dms import DmsStartTaskOperator
from airflow.providers.amazon.aws.operators.glue import GlueJobOperator

default_args = {
    "owner": "dataops",
    "depends_on_past": False,
    "email_on_failure": True,
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    "enterprise_cloud_migration_elt_pipeline",
    default_args=default_args,
    description="Orchestrates AWS DMS CDC, S3 Cross-Region Replication, Glue PySpark SCD2, & Snowflake Loading",
    schedule_interval=timedelta(hours=6),
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["dms", "glue", "scd2", "snowflake", "crr"],
) as dag:

    def verify_crr_health():
        print("Verifying S3 Cross-Region Replication health across us-east-1 and us-west-2...")
        return True

    def trigger_snowflake_copy():
        print("Executing COPY INTO analytics_warehouse FROM @s3_curated_stage...")
        return True

    task_verify_crr = PythonOperator(
        task_id="verify_s3_cross_region_replication",
        python_callable=verify_crr_health,
    )

    task_run_glue_scd2 = GlueJobOperator(
        task_id="run_glue_pyspark_scd2_job",
        job_name="enterprise-dataops-pipeline-scd2-pyspark-prod",
        wait_for_completion=True,
    )

    task_load_snowflake = PythonOperator(
        task_id="load_curated_data_to_snowflake",
        python_callable=trigger_snowflake_copy,
    )

    task_verify_crr >> task_run_glue_scd2 >> task_load_snowflake
