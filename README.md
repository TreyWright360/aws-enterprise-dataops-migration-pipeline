# Enterprise Cloud Migration, Real-Time Streaming & DataOps Pipeline on AWS

> **Portfolio evidence status:** The Terraform modules, transformation script, and DAG are published. No dated migration, throughput, recovery, or cost results are checked in. The [AWS Cloud Operations Handbook](https://github.com/TreyWright360/aws-cloud-operations-handbook) tracks the lab evidence needed for recruiter-facing claims.

See the [project case study](CASE-STUDY.md) for implementation, failure modes, evidence status, and production gaps.

[![Terraform](https://img.shields.io/badge/IaC-Terraform_1.8+-623CE4.svg?logo=terraform)](https://www.terraform.io)
[![AWS](https://img.shields.io/badge/AWS-DMS_|_Glue_|_Kinesis_|_S3_CRR-FF9900.svg?logo=amazon-aws)](https://aws.amazon.com)
[![Airflow](https://img.shields.io/badge/Orchestration-Apache_Airflow-017CEE.svg?logo=apache-airflow)](https://airflow.apache.org)
[![Snowflake](https://img.shields.io/badge/Data_Warehouse-Snowflake-29B5E8.svg?logo=snowflake)](https://www.snowflake.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A portfolio architecture using modular Terraform for AWS DMS, a Kinesis stream, S3 cross-region replication, and Glue, alongside an Airflow DAG and PySpark SCD2 transformation. The code shows the intended data flow; an end-to-end migration, event producer/consumer, Snowflake integration, recovery time, and throughput still need to be demonstrated with lab evidence.

---

## 🏗️ Architectural Topology

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│               ENTERPRISE CLOUD MIGRATION & DATAOPS ARCHITECTURE                        │
└────────────────────────────────────────────────────────────────────────────────────────┘

 [ On-Premise Relational DB ]              [ IoT / Sensor Event Producers ]
            │                                             │
            ▼ (CDC Replication)                           ▼ (Real-Time Streams)
 ┌───────────────────────┐                     ┌───────────────────────┐
 │ AWS Database Migration│                     │ Amazon Kinesis Stream │
 │ Service (DMS Task)    │                     │ (KMS AES-256 Encrypt) │
 └──────────┬────────────┘                     └──────────┬────────────┘
            │ (Parquet / Gzip)                            │
            └──────────────────────┬──────────────────────┘
                                   ▼
                   ┌────────────────────────────────┐
                   │  Primary S3 Data Lake (us-east-1)
                   │  (Versioning, Intelligent-Tier)│
                   └───────────────┬────────────────┘
                                   │
              ┌────────────────────┴────────────────────┐
              │ (Cross-Region Replication CRR)          │ (PySpark Batch/SCD2)
              ▼                                         ▼
 ┌────────────────────────────────┐            ┌────────────────────────────────┐
 │ Disaster Recovery S3 Data Lake │            │ AWS Glue ETL Catalog & Crawler │
 │ (us-west-2 Secondary Region)   │            └───────────────┬────────────────┘
 └────────────────────────────────┘                            │
                                                               ▼ (Orchestrated by Airflow)
                                               ┌────────────────────────────────┐
                                               │ Snowflake Cloud Data Warehouse │
                                               │ (Curated Dimensional Models)   │
                                               └────────────────────────────────┘
```

---

## 🛡️ Well-Architected Framework (WAF) Alignment

| WAF Pillar | Architectural Implementation |
| :--- | :--- |
| **1. Operational Excellence** | Automated end-to-end pipeline orchestration via Apache Airflow DAGs; modular Terraform IaC with GitHub Actions CI/CD. |
| **2. Security** | S3 bucket isolation with Block Public Access; customer-managed KMS AES-256 encryption at rest; least-privilege IAM roles for DMS, Glue, and Kinesis. |
| **3. Reliability** | S3 Cross-Region Replication (CRR) is defined; RPO/RTO require a timed recovery test. |
| **4. Performance Efficiency** | Parquet/GZIP and Kinesis are design choices; benchmark results are not yet available. |
| **5. Cost Optimization** | S3 Intelligent-Tiering and lifecycle transitions to Standard-IA; Glue serverless worker auto-scaling scaling to zero when idle. |
| **6. Sustainability** | Serverless compute primitives (AWS Glue G.1X workers & Lambda) eliminate idle EC2 instances. |

---

## 🏛️ Architecture Decision Records (ADRs)

* **ADR 001: AWS DMS with S3 Parquet Target vs. Direct Database-to-Database Sync**
  * *Decision:* Landed all CDC data into S3 as Parquet files before loading downstream warehouses.
  * *Rationale:* Decouples analytical workloads from production transactional systems, eliminates lock contention, and provides a durable, replayable raw data lake.
* **ADR 002: S3 Cross-Region Replication (CRR) for Enterprise Disaster Recovery**
  * *Decision:* Implemented automated asynchronous replication between `us-east-1` (Primary) and `us-west-2` (Secondary).
  * *Rationale:* Complies with enterprise business continuity mandates, ensuring data availability even in the event of an entire AWS regional outage.
* **ADR 003: Slowly Changing Dimensions Type 2 (SCD2) via AWS Glue PySpark**
  * *Decision:* Implemented SCD2 with effective dates and current record flags.
  * *Rationale:* Preserves historical auditability for all database mutations and state changes over time.

---

## 🚀 Quickstart Deployment

```bash
# 1. Clone repository
git clone https://github.com/TreyWright360/aws-enterprise-dataops-migration-pipeline.git
cd aws-enterprise-dataops-migration-pipeline

# 2. Initialize Terraform
terraform init

# 3. Plan deployment
terraform plan -var-file="environments/prod.tfvars"

# 4. Provision infrastructure
terraform apply -var-file="environments/dev.tfvars"
```
