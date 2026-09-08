resource "aws_iam_role" "dms_s3_target_role" {
  name = "${var.project_name}-dms-s3-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "dms.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "dms_s3_target_policy" {
  name = "${var.project_name}-dms-s3-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:PutObjectTagging"
        ]
        Resource = "${var.target_s3_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = var.target_s3_bucket_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dms_s3_attach" {
  role       = aws_iam_role.dms_s3_target_role.name
  policy_arn = aws_iam_policy.dms_s3_target_policy.arn
}

# DMS Target Endpoint (S3 Data Lake)
resource "aws_dms_endpoint" "target_s3" {
  endpoint_id   = "${var.project_name}-s3-target-${var.environment}"
  endpoint_type = "target"
  engine_name   = "s3"

  s3_settings {
    service_access_role_arn = aws_iam_role.dms_s3_target_role.arn
    bucket_name             = var.target_s3_bucket_name
    data_format             = "parquet"
    date_partition_enabled  = true
    compression_type        = "GZIP"
  }
}

# DMS Source Endpoint (Simulated On-Premise Relational DB)
resource "aws_dms_endpoint" "source_db" {
  endpoint_id   = "${var.project_name}-src-db-${var.environment}"
  endpoint_type = "source"
  engine_name   = "postgres"
  server_name   = "db-onprem.corp.internal"
  port          = 5432
  database_name = "production_orders"
  username      = "dms_user"
  password      = "SecureDmsPass123!"
  ssl_mode      = "require"
}

# DMS Replication Task with CDC (Change Data Capture)
resource "aws_dms_replication_task" "migration_cdc" {
  replication_task_id      = "${var.project_name}-cdc-task-${var.environment}"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = "arn:aws:dms:us-east-1:123456789012:rep:EXAMPLE-REP-INSTANCE"
  source_endpoint_arn      = aws_dms_endpoint.source_db.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_s3.endpoint_arn

  table_mappings = jsonencode({
    rules = [
      {
        "rule-type" = "selection"
        "rule-id"   = "1"
        "rule-name" = "all-orders-schema"
        "object-locator" = {
          "schema-name" = "public"
          "table-name"  = "%"
        }
        "rule-action" = "include"
      }
    ]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      SupportLobs  = true
      FullLobMode  = false
      LobChunkSize = 64
    }
  })

  tags = {
    Name = "${var.project_name}-cdc-migration"
  }
}
