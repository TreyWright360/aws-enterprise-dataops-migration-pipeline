# Lab source: a small RDS PostgreSQL instance standing in for the
# on-premise database, plus the DMS replication instance that was
# previously referenced by a placeholder ARN. Uses the account's
# default VPC so no additional networking has to be provisioned.

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "random_password" "source_db" {
  length  = 20
  special = false
}

resource "aws_security_group" "source_db" {
  name        = "${var.project_name}-source-db-${var.environment}"
  description = "Allow PostgreSQL from the DMS replication instance only"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dms_replication" {
  name        = "${var.project_name}-dms-replication-${var.environment}"
  description = "DMS replication instance egress"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "source_db_from_dms" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.source_db.id
  source_security_group_id = aws_security_group.dms_replication.id
}

resource "aws_db_subnet_group" "source_db" {
  name       = "${var.project_name}-source-db-${var.environment}"
  subnet_ids = data.aws_subnets.default.ids
}

resource "aws_db_parameter_group" "source_db" {
  name   = "${var.project_name}-source-db-${var.environment}"
  family = "postgres18"

  parameter {
    name         = "rds.logical_replication"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "source" {
  identifier     = "${var.project_name}-source-db-${var.environment}"
  engine         = "postgres"
  engine_version = "18.3"
  instance_class = "db.t3.micro"

  allocated_storage   = 20
  storage_encrypted   = true
  publicly_accessible = false

  db_name  = "production_orders"
  username = "dms_user"
  password = random_password.source_db.result

  db_subnet_group_name   = aws_db_subnet_group.source_db.name
  parameter_group_name   = aws_db_parameter_group.source_db.name
  vpc_security_group_ids = [aws_security_group.source_db.id]

  backup_retention_period = 0
  skip_final_snapshot     = true
  apply_immediately       = true
}

resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_id          = "${var.project_name}-dms-subnets-${var.environment}"
  replication_subnet_group_description = "DMS replication instance subnets"
  subnet_ids                           = data.aws_subnets.default.ids
}

resource "aws_dms_replication_instance" "main" {
  replication_instance_id    = "${var.project_name}-dms-${var.environment}"
  replication_instance_class = "dms.t3.micro"
  allocated_storage          = 20
  publicly_accessible        = false

  replication_subnet_group_id = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids      = [aws_security_group.dms_replication.id]
}
