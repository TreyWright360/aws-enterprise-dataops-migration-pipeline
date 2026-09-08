terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.replica]
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. Destination Replica Bucket (in secondary region us-west-2)
resource "aws_s3_bucket" "replica" {
  provider      = aws.replica
  bucket        = "${var.project_name}-lake-dr-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = var.environment == "dev" ? true : false
}

resource "aws_s3_bucket_versioning" "replica_versioning" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_sse" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 2. IAM Role for S3 Cross-Region Replication
data "aws_iam_policy_document" "replication_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  name               = "${var.project_name}-s3-crr-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.replication_assume_role.json
}

data "aws_iam_policy_document" "replication_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.primary.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]
    resources = ["${aws_s3_bucket.primary.arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags"
    ]
    resources = ["${aws_s3_bucket.replica.arn}/*"]
  }
}

resource "aws_iam_policy" "replication_policy_attach" {
  name   = "${var.project_name}-s3-crr-policy-${var.environment}"
  policy = data.aws_iam_policy_document.replication_policy.json
}

resource "aws_iam_role_policy_attachment" "replication_attach" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication_policy_attach.arn
}

# 3. Primary Data Lake Bucket (in primary region us-east-1)
resource "aws_s3_bucket" "primary" {
  bucket        = "${var.project_name}-lake-primary-${var.environment}-${random_id.bucket_suffix.hex}"
  force_destroy = var.environment == "dev" ? true : false
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary_sse" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  depends_on = [aws_s3_bucket_versioning.primary_versioning, aws_s3_bucket_versioning.replica_versioning]
  role       = aws_iam_role.replication.arn
  bucket     = aws_s3_bucket.primary.id

  rule {
    id     = "disaster-recovery-crr"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}
