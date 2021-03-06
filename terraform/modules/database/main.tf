
module "rds_security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "3.2.0"

  name        = "${var.project}-${var.environment}-rds-sg"
  description = "Security group for RDS DB"
  vpc_id      = "${var.vpc_id}"

  number_of_computed_ingress_with_source_security_group_id = 1
  computed_ingress_with_source_security_group_id = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL from EKS"
      source_security_group_id = "${var.allowed_security_group_id}"
    },
  ]

  egress_rules        = ["all-all"]

  tags = {
    Env  = "${var.environment}"
  }
}

data "aws_caller_identity" "current" {
}

# This is created by bootstrap/secrets
data "aws_secretsmanager_secret_version" "rds_master_secret" {
  secret_id = "${var.project}-${var.environment}-rds-master-password"
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "2.4.0"

  identifier = "${var.project}-${var.environment}"

  engine            = "postgres"
  engine_version    = "11.5"
  instance_class    = var.instance_class
  allocated_storage = var.storage_gb
  storage_encrypted = true

  name     = "${replace(var.project, "-", "")}"
  username = "master_user"
  password = "${data.aws_secretsmanager_secret_version.rds_master_secret.secret_string}"
  port     = "5432"

  vpc_security_group_ids = ["${module.rds_security_group.this_security_group_id}"]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  # disable backups to create DB faster in non-production environments
  backup_retention_period = var.environment == "production" ? 30 : 0

  # Subnet is created by the vpc module
  create_db_subnet_group = false
  db_subnet_group_name = "${var.project}-${var.environment}-vpc"

  # DB parameter and option group
  family = "postgres11"
  major_engine_version = "11.5"

  final_snapshot_identifier = "final-snapshot"
  deletion_protection = true

  # Enhanced monitoring
  performance_insights_enabled = true
  monitoring_interval = "30"
  monitoring_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/rds-monitoring-role"

  tags = {
    Name = "${var.project}-${var.environment}-rds-postgres"
    Env  = "${var.environment}"
  }
}
