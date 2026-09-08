# Root Configuration - Enterprise DataOps & Migration Pipeline

module "s3_cross_region_replication" {
  source             = "./modules/s3_cross_region_replication"
  project_name       = var.project_name
  environment        = var.environment
  aws_primary_region = var.aws_primary_region
  aws_replica_region = var.aws_replica_region
  providers = {
    aws.replica = aws.replica
  }
}

module "dms_migration" {
  source                = "./modules/dms_migration"
  project_name          = var.project_name
  environment           = var.environment
  target_s3_bucket_arn  = module.s3_cross_region_replication.primary_bucket_arn
  target_s3_bucket_name = module.s3_cross_region_replication.primary_bucket_name
}

module "streaming_ingestion" {
  source                = "./modules/streaming_ingestion"
  project_name          = var.project_name
  environment           = var.environment
  destination_s3_bucket = module.s3_cross_region_replication.primary_bucket_name
}

module "glue_etl" {
  source                  = "./modules/glue_etl"
  project_name            = var.project_name
  environment             = var.environment
  s3_data_lake_bucket_arn = module.s3_cross_region_replication.primary_bucket_arn
  s3_data_lake_bucket     = module.s3_cross_region_replication.primary_bucket_name
}
