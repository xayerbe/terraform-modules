locals {
  engine_resolved = var.engine == "aurora" ? "aurora-mysql" : var.engine
  is_aurora       = contains(["aurora-mysql", "aurora-postgresql"], local.engine_resolved)
  is_cluster      = local.is_aurora ? true : var.is_cluster
  allow_replicas  = !local.is_cluster && contains(["mysql", "postgres"], local.engine_resolved)

  engine_port = {
    mysql             = 3306
    aurora            = 3306
    "aurora-mysql"    = 3306
    postgres          = 5432
    "aurora-postgresql" = 5432
  }

  instance_type_defaults = {
    mysql             = "db.t3.micro"
    postgres          = "db.t3.micro"
    "aurora-mysql"    = "db.t3.small"
    "aurora-postgresql" = "db.t3.small"
  }

  kms_needed = var.storage_encrypted && var.kms_key_arn == null
  kms_arn    = var.kms_key_arn != null ? var.kms_key_arn : (local.kms_needed ? aws_kms_key.rds[0].arn : null)
}

resource "aws_kms_key" "rds" {
  count = local.kms_needed ? 1 : 0

  description             = "KMS para RDS (${var.name_prefix})."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-kms"
  })
}

resource "aws_kms_alias" "rds" {
  count = local.kms_needed ? 1 : 0

  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds[0].key_id
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-subnets"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-subnets"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-rds-sg"
  description = "RDS SG for ${var.name_prefix}"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-rds-sg"
  })
}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

resource "aws_security_group_rule" "ingress" {
  for_each = {
    for idx, rule in var.ingress_rules : idx => rule
  }

  type                     = "ingress"
  security_group_id        = aws_security_group.this.id
  from_port                = local.engine_port[local.engine_resolved]
  to_port                  = local.engine_port[local.engine_resolved]
  protocol                 = "tcp"
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_sg_id", null)
  description              = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "egress" {
  for_each = {
    for idx, rule in var.egress_rules : idx => rule
  }

  type                     = "egress"
  security_group_id        = aws_security_group.this.id
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  cidr_blocks              = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_sg_id", null)
  description              = lookup(each.value, "description", null)
}

resource "aws_db_instance" "standalone" {
  count = local.is_cluster ? 0 : 1

  identifier             = "${var.name_prefix}-db"
  engine                 = local.engine_resolved
  engine_version         = var.engine_version
  instance_class         = coalesce(var.instance_type, local.instance_type_defaults[local.engine_resolved])
  username               = var.username
  password               = var.password
  db_name                = var.db_name
  port                   = local.engine_port[local.engine_resolved]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = var.publicly_accessible
  multi_az               = var.multi_az

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = var.storage_type
  storage_encrypted     = var.storage_encrypted
  kms_key_id            = local.kms_arn

  backup_retention_period = var.backup_retention_days
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-db"
  })
}

resource "aws_db_instance" "read_replica" {
  count = local.allow_replicas ? var.read_replica_count : 0

  identifier             = "${var.name_prefix}-replica-${count.index + 1}"
  replicate_source_db    = aws_db_instance.standalone[0].id
  instance_class         = coalesce(var.instance_type, local.instance_type_defaults[local.engine_resolved])
  publicly_accessible    = var.publicly_accessible
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  storage_encrypted = var.storage_encrypted
  kms_key_id        = local.kms_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-replica-${count.index + 1}"
  })
}

resource "aws_rds_cluster" "this" {
  count = local.is_cluster ? 1 : 0

  cluster_identifier     = "${var.name_prefix}-cluster"
  engine                 = local.engine_resolved
  engine_version         = var.engine_version
  database_name          = var.db_name
  master_username        = var.username
  master_password        = var.password
  port                   = local.engine_port[local.engine_resolved]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  storage_encrypted     = var.storage_encrypted
  kms_key_id            = local.kms_arn
  backup_retention_period = var.backup_retention_days

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

resource "aws_rds_cluster_instance" "this" {
  count = local.is_cluster ? var.cluster_instance_count : 0

  identifier         = "${var.name_prefix}-cluster-${count.index + 1}"
  cluster_identifier = aws_rds_cluster.this[0].id
  engine             = local.engine_resolved
  engine_version     = var.engine_version
  instance_class     = coalesce(var.instance_type, local.instance_type_defaults[local.engine_resolved])
  publicly_accessible = var.publicly_accessible

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-cluster-${count.index + 1}"
  })
}
