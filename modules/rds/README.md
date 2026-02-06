# RDS Module

This module creates a standalone RDS database or an Aurora cluster, with optional encryption, subnet group, and security group.

## Usage example

```hcl
module "rds" {
  source = "./modules/rds"

  name_prefix = "app"
  engine      = "postgres"

  username = "admin"
  password = "supersecret"

  subnet_ids = [
    "subnet-11111111",
    "subnet-22222222"
  ]

  storage_encrypted = true
  kms_key_arn       = null

  ingress_rules = [
    {
      cidr_blocks = ["10.0.0.0/16"]
      description = "App access"
    }
  ]

  tags = {
    Environment = "dev"
  }
}
```

## Variables

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name_prefix` | `string` | n/a | Prefix for resources. |
| `engine` | `string` | `"mysql"` | Engine: mysql, postgres, aurora, aurora-mysql, aurora-postgresql. |
| `engine_version` | `string` | `null` | Engine version. If null, AWS picks the recommended/default. |
| `is_cluster` | `bool` | `false` | If true, creates a cluster (Aurora only). |
| `cluster_instance_count` | `number` | `2` | Cluster instances (writer + readers). |
| `instance_type` | `string` | `null` | Instance type (if null, uses the smallest per engine). |
| `db_name` | `string` | `null` | Initial database name. |
| `username` | `string` | n/a | Master username. |
| `password` | `string` | n/a | Master password. |
| `subnet_ids` | `list(string)` | n/a | Subnets for the subnet group. |
| `storage_encrypted` | `bool` | `false` | Encrypts storage. |
| `kms_key_arn` | `string` | `null` | KMS for encryption. If null and encrypted=true, one is created. |
| `allocated_storage` | `number` | `20` | Storage (GiB) for standalone. |
| `max_allocated_storage` | `number` | `100` | Max storage autoscaling. |
| `storage_type` | `string` | `"gp3"` | Storage type. |
| `backup_retention_days` | `number` | `7` | Backup retention days. |
| `publicly_accessible` | `bool` | `false` | Publicly accessible. |
| `multi_az` | `bool` | `false` | Multi-AZ for standalone. |
| `read_replica_count` | `number` | `0` | Number of read replicas for MySQL/PostgreSQL (standalone). |
| `ingress_rules` | `list(object)` | `[]` | Ingress rules (port depends on engine). |
| `egress_rules` | `list(object)` | `[...]` | Egress rules (default any). |
| `tags` | `map(string)` | `{}` | Common tags. |

## Outputs

| Name | Description |
| --- | --- |
| `security_group_id` | Security Group ID. |
| `subnet_group_name` | Subnet group name. |
| `endpoint` | Primary endpoint. |
| `reader_endpoint` | Reader endpoint (cluster only). |
| `identifier` | DB/cluster identifier. |
| `read_replica_ids` | Read replica IDs (if any). |
| `kms_key_arn` | KMS ARN used (if any). |
