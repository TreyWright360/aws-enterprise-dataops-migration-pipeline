output "glue_database_name" { value = aws_glue_catalog_database.data_lake_db.name }
output "glue_job_name" { value = aws_glue_job.scd2_transformation.name }
