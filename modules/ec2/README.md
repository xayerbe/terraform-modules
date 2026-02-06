# EC2 Module

This module creates one or more EC2 instances with a Security Group, IAM role/profile for SSM, additional disks, and market options (on-demand or spot).

## Usage example

```hcl
module "ec2" {
  source = "./modules/ec2"

  name      = "app"
  subnet_id = "subnet-123456"

  instance_count = 2
  instance_type  = "t3.micro"
  market_type    = "on_demand"

  ami_lookup = "ubuntu-latest"

  volume_sizes     = [30, 50]
  volume_type      = "gp3"
  volume_encrypted = true

  ingress_rules = [
    {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/16"]
      description = "Internal SSH"
    }
  ]

  egress_rules = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  user_data = ""

  tags = {
    Environment = "dev"
  }

  volume_tags = {
    Backup = "true"
  }
}
```

## Variables

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | n/a | Base name for instances and related resources. |
| `subnet_id` | `string` | n/a | Subnet where instances are launched. |
| `instance_count` | `number` | `1` | Number of identical instances. |
| `instance_type` | `string` | `"t3.micro"` | Instance type. |
| `market_type` | `string` | `"on_demand"` | `on_demand` or `spot`. |
| `ami_id` | `string` | `null` | Explicit AMI ID. |
| `ami_lookup` | `string` | `"ubuntu-latest"` | AMI alias (resolved via SSM Parameter Store) when `ami_id` is null. |
| `ami_ssm_parameter_name` | `string` | `null` | Override SSM parameter name for AMI lookup. |
| `volume_sizes` | `list(number)` | `[]` | Disk sizes (GiB). The first is root. |
| `volume_type` | `string` | `"gp3"` | EBS volume type. |
| `volume_encrypted` | `bool` | `false` | Encrypt volumes. |
| `volume_kms_key_arn` | `string` | `null` | KMS for volumes. If null and encrypted, one is created. |
| `ingress_rules` | `list(object)` | `[]` | Ingress rules (port/protocol/source). |
| `egress_rules` | `list(object)` | `[...]` | Egress rules (default allow all). |
| `instance_profile_name` | `string` | `null` | Existing instance profile. If null, one is created. |
| `user_data` | `string` | `""` | User data. |
| `enable_metadata_options` | `bool` | `true` | Enforces IMDSv2 when true. |
| `metadata_hop_limit` | `number` | `1` | IMDS hop limit. |
| `tags` | `map(string)` | `{}` | Common tags. |
| `volume_tags` | `map(string)` | `{}` | Additional volume tags. |

## Outputs

| Name | Description |
| --- | --- |
| `instance_ids` | Instance IDs. |
| `private_ips` | Private IPs of the instances. |
| `public_ips` | Public IPs of the instances. |
| `security_group_id` | Security Group ID. |
| `instance_profile_name` | Instance profile in use. |
| `volume_kms_key_arn` | KMS used for volumes, if applicable. |

## Notes

- If you pass `instance_profile_name`, the module will not create or modify IAM.
- To use SSM, the AMI must include the SSM agent or install it via `user_data`.
- `ami_lookup` uses AWS SSM public parameters for latest AMI IDs. Use `ami_ssm_parameter_name` if you need a custom path.
