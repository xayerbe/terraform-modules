locals {
  is_spot = var.market_type == "spot"

  ami_owners = {
    "ubuntu-latest"       = ["099720109477"]
    "amazonlinux2-latest" = ["137112412989"]
  }

  ami_name_filters = {
    "ubuntu-latest"       = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
    "amazonlinux2-latest" = "amzn2-ami-hvm-*-x86_64-gp2"
  }

  additional_volume_sizes = length(var.volume_sizes) > 1 ? slice(var.volume_sizes, 1, length(var.volume_sizes)) : []
  device_letters          = ["f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p"]

  create_kms = var.volume_encrypted && var.volume_kms_key_arn == null
  kms_arn    = var.volume_kms_key_arn != null ? var.volume_kms_key_arn : (local.create_kms ? aws_kms_key.volume[0].arn : null)
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_ami" "selected" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = local.ami_owners[var.ami_lookup]

  filter {
    name   = "name"
    values = [local.ami_name_filters[var.ami_lookup]]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_kms_key" "volume" {
  count = local.create_kms ? 1 : 0

  description             = "KMS para volúmenes EC2 (${var.name})."
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name = "${var.name}-volume-kms"
  })
}

resource "aws_kms_alias" "volume" {
  count = local.create_kms ? 1 : 0

  name          = "alias/${var.name}-volume"
  target_key_id = aws_kms_key.volume[0].key_id
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "SG for ${var.name}"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-sg"
  })
}

resource "aws_security_group_rule" "ingress" {
  for_each = {
    for idx, rule in var.ingress_rules : idx => rule
  }

  type              = "ingress"
  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_sg_id", null)
  description       = lookup(each.value, "description", null)
}

resource "aws_security_group_rule" "egress" {
  for_each = {
    for idx, rule in var.egress_rules : idx => rule
  }

  type              = "egress"
  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = lookup(each.value, "cidr_blocks", null)
  source_security_group_id = lookup(each.value, "source_sg_id", null)
  description       = lookup(each.value, "description", null)
}

data "aws_iam_policy_document" "assume_role" {
  count = var.instance_profile_name == null ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  count = var.instance_profile_name == null ? 1 : 0

  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role[0].json

  tags = merge(var.tags, {
    Name = "${var.name}-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.instance_profile_name == null ? 1 : 0

  role       = aws_iam_role.this[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "this" {
  count = var.instance_profile_name == null ? 1 : 0

  name = "${var.name}-profile"
  role = aws_iam_role.this[0].name
}

resource "aws_instance" "this" {
  count         = var.instance_count
  ami           = var.ami_id != null ? var.ami_id : data.aws_ami.selected[0].id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.this.id]
  iam_instance_profile   = var.instance_profile_name != null ? var.instance_profile_name : aws_iam_instance_profile.this[0].name

  user_data = var.user_data != "" ? var.user_data : null

  dynamic "instance_market_options" {
    for_each = local.is_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "terminate"
      }
    }
  }

  dynamic "metadata_options" {
    for_each = var.enable_metadata_options ? [1] : []
    content {
      http_endpoint               = "enabled"
      http_tokens                 = "required"
      http_put_response_hop_limit = var.metadata_hop_limit
    }
  }

  root_block_device {
    volume_size = length(var.volume_sizes) > 0 ? var.volume_sizes[0] : null
    volume_type = var.volume_type
    encrypted   = var.volume_encrypted
    kms_key_id  = local.kms_arn
  }

  dynamic "ebs_block_device" {
    for_each = {
      for idx, size in local.additional_volume_sizes : idx => size
    }

    content {
      device_name = "/dev/sd${local.device_letters[ebs_block_device.key]}"
      volume_size = ebs_block_device.value
      volume_type = var.volume_type
      encrypted   = var.volume_encrypted
      kms_key_id  = local.kms_arn
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${count.index + 1}"
  })

  volume_tags = merge(var.tags, var.volume_tags)
}
