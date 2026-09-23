resource "aws_glue_catalog_database" "data_lake_db" {
  name        = "${var.project_name}_catalog_${var.environment}"
  description = "AWS Glue Data Catalog database for DMS & Streaming ingestion"
}

resource "aws_iam_role" "glue_service_role" {
  name = "${var.project_name}-glue-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "glue.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "glue_service_attach" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_policy" "glue_s3_policy" {
  name = "${var.project_name}-glue-s3-policy-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_data_lake_bucket_arn,
          "${var.s3_data_lake_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_s3_attach" {
  role       = aws_iam_role.glue_service_role.name
  policy_arn = aws_iam_policy.glue_s3_policy.arn
}

# The job definition below only points at this location; Terraform
# never actually uploaded the script here, so the job would fail
# immediately with a missing-script error on its first real run.
resource "aws_s3_object" "scd2_script" {
  bucket = var.s3_data_lake_bucket
  key    = "scripts/pyspark_scd2_transform.py"
  source = "${path.module}/../../src/scripts/pyspark_scd2_transform.py"
  etag   = filemd5("${path.module}/../../src/scripts/pyspark_scd2_transform.py")
}

resource "aws_glue_job" "scd2_transformation" {
  name     = "${var.project_name}-scd2-pyspark-${var.environment}"
  role_arn = aws_iam_role.glue_service_role.arn

  command {
    script_location = "s3://${var.s3_data_lake_bucket}/scripts/pyspark_scd2_transform.py"
    python_version  = "3"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--source_bucket"                    = var.s3_data_lake_bucket
    "--table_path"                       = "public/orders"
  }

  depends_on = [aws_s3_object.scd2_script]
}
