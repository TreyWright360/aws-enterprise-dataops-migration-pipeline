output "primary_data_lake_bucket" {
  description = "Primary S3 Data Lake bucket in us-east-1"
  value       = module.s3_cross_region_replication.primary_bucket_name
}

output "dr_replica_data_lake_bucket" {
  description = "Disaster Recovery S3 Replica bucket in us-west-2"
  value       = module.s3_cross_region_replication.replica_bucket_name
}

output "dms_replication_task_arn" {
  description = "AWS DMS Replication Task ARN"
  value       = module.dms_migration.replication_task_arn
}

output "streaming_kinesis_arn" {
  description = "Kinesis Data Stream ARN for Real-Time Streaming"
  value       = module.streaming_ingestion.stream_arn
}

output "glue_database_name" {
  description = "AWS Glue Catalog Database Name"
  value       = module.glue_etl.glue_database_name
}
