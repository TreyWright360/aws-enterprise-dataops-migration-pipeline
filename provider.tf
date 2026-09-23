terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "trey-portfolio-tfstate-050451394862"
    key            = "dataops/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "portfolio-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_primary_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Repository  = "aws-enterprise-dataops-migration-pipeline"
      Compliance  = "Well-Architected-DataOps"
    }
  }
}

provider "aws" {
  alias  = "replica"
  region = var.aws_replica_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Role        = "DisasterRecoveryReplica"
      ManagedBy   = "Terraform"
    }
  }
}
