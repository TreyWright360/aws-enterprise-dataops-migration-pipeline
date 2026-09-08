variable "aws_primary_region" {
  description = "Primary AWS region for active data pipelines"
  type        = string
  default     = "us-east-1"
}

variable "aws_replica_region" {
  description = "Secondary AWS region for Cross-Region Disaster Recovery"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name identifier"
  type        = string
  default     = "enterprise-dataops-pipeline"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "vpc_subnet_ids" {
  description = "Subnet IDs for DMS Replication Instance"
  type        = list(string)
  default     = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
}
