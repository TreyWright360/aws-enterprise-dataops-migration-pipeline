# Case study: AWS migration and DataOps architecture

**Portfolio status:** PARTIALLY TESTED. Deployed live to AWS on 2026-09-23. A real DMS full load moved seeded data from RDS PostgreSQL into the S3 Parquet lake with 0 errors, validated by reading the actual values back out of the migrated Parquet file. CDC apply, cross-region replication, Glue SCD2, and Kinesis streaming remain untested.

## Business problem

Model how change data and event data could move into a governed data lake, transform into historical analytical records, and survive loss of the primary region. This is a portfolio design, not a measured enterprise migration.

## Architecture and technologies

[Root Terraform](main.tf) wires [DMS](modules/dms_migration/main.tf), a [Kinesis stream](modules/streaming_ingestion/main.tf), [S3 cross-region replication](modules/s3_cross_region_replication/main.tf), and [Glue](modules/glue_etl/main.tf). The repository also contains a [PySpark SCD2 script](src/scripts/pyspark_scd2_transform.py) and an [Airflow DAG](dags/enterprise_migration_elt_dag.py).

## What is implemented

The repository defines infrastructure components and processing code. It does not contain a complete event producer/consumer or captured end-to-end source-to-warehouse execution. Snowflake delivery, replication lag, RTO, and RPO remain to be tested.

## Failure modes and runbooks

The [handbook failure map](https://github.com/TreyWright360/aws-cloud-operations-handbook/blob/main/architecture/master-failure-map.md) covers connectivity, IAM, backup, and DR failure points. A regional recovery runbook is planned in the [content index](https://github.com/TreyWright360/aws-cloud-operations-handbook/blob/main/CONTENT-INDEX.md).

## Test evidence and video

**PARTIALLY TESTED.** [Dated evidence](https://github.com/TreyWright360/aws-cloud-operations-handbook/blob/main/evidence/dataops-dms-migration/INDEX.md) covers a real DMS full-load run: 5 rows moved from RDS PostgreSQL to S3 as Parquet, 0 errors, content verified from the downloaded file. No CDC apply validation, streaming throughput, SCD2 correctness result, restore timeline, or video is checked in yet.

## Security and cost controls

The design uses managed service roles and encryption options in Terraform. DMS replication, Kinesis shards, Glue jobs, and cross-region transfer can incur charges even when the pipeline is idle. Estimate and monitor these before a lab run.

## Production improvements

Add end-to-end integration tests, data quality checks, lag alarms, replay and deduplication controls, a rehearsed regional recovery sequence, least-privilege review, and measured cost/performance results.

## CI/CD and deployment validation

- **CI status:** Verified passing without AWS credentials or terraform apply on PR and main push.
- **PR validation run:** [Run #35787070528](https://github.com/TreyWright360/aws-enterprise-dataops-migration-pipeline/actions/runs/35787070528) (passed)
- **Main branch validation run:** [Run #35787171875](https://github.com/TreyWright360/aws-enterprise-dataops-migration-pipeline/actions/runs/35787171875) (passed, non-deploying)
- **Deployment safeguards:** Automatic deployment is removed from push to `main`. Deployment is isolated in `.github/workflows/deploy-production.yml`, requiring manual `workflow_dispatch` trigger and approval via the protected `production` environment.


