output "target_endpoint_arn" { value = aws_dms_endpoint.target_s3.endpoint_arn }
output "source_endpoint_arn" { value = aws_dms_endpoint.source_db.endpoint_arn }
output "replication_task_arn" { value = aws_dms_replication_task.migration_cdc.replication_task_arn }
