# Case study: AWS migration and DataOps architecture

**Portfolio status:** Infrastructure and transformation code published; end-to-end migration and recovery untested in the repository.

## Business problem

Model how change data and event data could move into a governed data lake, transform into historical analytical records, and survive loss of the primary region. This is a portfolio design, not a measured enterprise migration.

## Architecture and technologies

[Root Terraform](main.tf) wires [DMS](modules/dms_migration/main.tf), a [Kinesis stream](modules/streaming_ingestion/main.tf), [S3 cross-region replication](modules/s3_cross_region_replication/main.tf), and [Glue](modules/glue_etl/main.tf). The repository also contains a [PySpark SCD2 script](src/scripts/pyspark_scd2_transform.py) and an [Airflow DAG](dags/enterprise_migration_elt_dag.py).

## What is implemented

The repository defines infrastructure components and processing code. It does not contain a complete event producer/consumer or captured end-to-end source-to-warehouse execution. Snowflake delivery, replication lag, RTO, and RPO remain to be tested.

## Failure modes and runbooks

The [handbook failure map](https://github.com/TreyWright360/aws-cloud-operations-handbook/blob/main/architecture/master-failure-map.md) covers connectivity, IAM, backup, and DR failure points. A regional recovery runbook is planned in the [content index](https://github.com/TreyWright360/aws-cloud-operations-handbook/blob/main/CONTENT-INDEX.md).

## Test evidence and video

**DOCUMENTATION ONLY.** No dated DMS CDC validation, streaming throughput, SCD2 correctness result, restore timeline, or video is checked in.

## Security and cost controls

The design uses managed service roles and encryption options in Terraform. DMS replication, Kinesis shards, Glue jobs, and cross-region transfer can incur charges even when the pipeline is idle. Estimate and monitor these before a lab run.

## Production improvements

Add end-to-end integration tests, data quality checks, lag alarms, replay and deduplication controls, a rehearsed regional recovery sequence, least-privilege review, and measured cost/performance results.

## CI/CD and deployment validation

- **CI status:** Repair in progress (repaired invalid `secrets.*` job-level condition, awaiting validation run).
- **PR validation run:** Pending PR checks
- **Main branch validation run:** Pending merge to main
- **Deployment safeguards:** Automatic deployment is removed from push to `main`. Deployment is isolated in `.github/workflows/deploy-production.yml`, requiring manual `workflow_dispatch` trigger and approval via the protected `production` environment.

