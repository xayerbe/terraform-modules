locals {
  azs_full = [
    for az in var.azs : can(regex("^${var.region}", az)) ? az : "${var.region}${az}"
  ]

  az_map = merge(
    { for idx, az in var.azs : az => local.azs_full[idx] },
    { for az_full in local.azs_full : az_full => az_full }
  )

  public_subnets = {
    for subnet in var.public_subnets :
    subnet.name => merge(subnet, { az_full = lookup(local.az_map, subnet.az, subnet.az) })
  }

  private_subnets = {
    for subnet in var.private_subnets :
    subnet.name => merge(subnet, { az_full = lookup(local.az_map, subnet.az, subnet.az) })
  }

  public_subnets_by_az = {
    for key, subnet in local.public_subnets : subnet.az_full => key
  }

  create_flow_logs_bucket = var.enable_flow_logs && var.flow_logs_s3_bucket_name == null
  create_flow_logs_kms    = var.enable_flow_logs && var.flow_logs_kms_key_arn == null

  flow_logs_bucket_name = var.flow_logs_s3_bucket_name != null ? var.flow_logs_s3_bucket_name : "${var.vpc_name}-flowlogs"
  flow_logs_bucket_arn  = "arn:aws:s3:::${local.flow_logs_bucket_name}"

  flow_logs_kms_key_arn = var.flow_logs_kms_key_arn != null ? var.flow_logs_kms_key_arn : (
    local.create_flow_logs_kms ? aws_kms_key.flow_logs[0].arn : null
  )

  natgw_azs = var.create_natgw ? (
    length(var.natgw_azs) > 0 ? [for az in var.natgw_azs : lookup(local.az_map, az, az)] : [local.azs_full[0]]
  ) : []

  natgw_subnet_keys = {
    for az in local.natgw_azs : az => local.public_subnets_by_az[az]
  }
}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

resource "aws_vpc_dhcp_options" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  domain_name         = coalesce(var.dhcp_options_domain_name, "${var.region}.compute.internal")
  domain_name_servers = var.dhcp_options_domain_name_servers

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-dhcp"
  })
}

resource "aws_vpc_dhcp_options_association" "this" {
  count = var.enable_dhcp_options ? 1 : 0

  vpc_id          = aws_vpc.this.id
  dhcp_options_id = aws_vpc_dhcp_options.this[0].id
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az_full
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az_full

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

resource "aws_internet_gateway" "this" {
  count  = var.create_igw ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-igw"
  })
}

resource "aws_eip" "natgw" {
  for_each = local.natgw_subnet_keys

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-natgw-${each.key}"
  })
}

resource "aws_nat_gateway" "this" {
  for_each = local.natgw_subnet_keys

  allocation_id = aws_eip.natgw[each.key].id
  subnet_id     = aws_subnet.public[each.value].id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-natgw-${each.key}"
  })
}

resource "aws_route_table" "public" {
  for_each = aws_subnet.public

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-public-${each.key}"
  })
}

resource "aws_route" "public_internet" {
  for_each = var.create_igw ? aws_route_table.public : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-private-${each.key}"
  })
}

resource "aws_route" "private_nat" {
  for_each = var.create_natgw ? {
    for key, subnet in aws_subnet.private :
    key => subnet if contains(keys(local.natgw_subnet_keys), subnet.availability_zone)
  } : {}

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.value.availability_zone].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_kms_key" "flow_logs" {
  count = local.create_flow_logs_kms ? 1 : 0

  description             = "KMS key for VPC flow logs (${var.vpc_name})."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-flowlogs-kms"
  })
}

resource "aws_kms_alias" "flow_logs" {
  count = local.create_flow_logs_kms ? 1 : 0

  name          = "alias/${var.vpc_name}-flowlogs"
  target_key_id = aws_kms_key.flow_logs[0].key_id
}

resource "aws_s3_bucket" "flow_logs" {
  count = local.create_flow_logs_bucket ? 1 : 0

  bucket = local.flow_logs_bucket_name

  tags = merge(var.tags, {
    Name = local.flow_logs_bucket_name
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  count = local.create_flow_logs_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.flow_logs_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  count = local.create_flow_logs_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id

  rule {
    id     = "flow-logs-expiration"
    status = "Enabled"

    expiration {
      days = var.flow_logs_retention_days
    }
  }
}

data "aws_iam_policy_document" "flow_logs_bucket" {
  count = local.create_flow_logs_bucket ? 1 : 0

  statement {
    sid     = "AWSLogDeliveryWrite"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = ["${local.flow_logs_bucket_arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }

  statement {
    sid     = "AWSLogDeliveryAclCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]

    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }

    resources = [local.flow_logs_bucket_arn]
  }
}

resource "aws_s3_bucket_policy" "flow_logs" {
  count = local.create_flow_logs_bucket ? 1 : 0

  bucket = aws_s3_bucket.flow_logs[0].id
  policy = data.aws_iam_policy_document.flow_logs_bucket[0].json
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  log_destination      = local.flow_logs_bucket_arn
  log_destination_type = "s3"
  traffic_type         = upper(var.flow_logs_traffic_type)

  tags = merge(var.tags, {
    Name = "${var.vpc_name}-flowlogs"
  })
}
