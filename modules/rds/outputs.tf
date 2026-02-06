output "security_group_id" {
  description = "ID del Security Group."
  value       = aws_security_group.this.id
}

output "subnet_group_name" {
  description = "Nombre del subnet group."
  value       = aws_db_subnet_group.this.name
}

output "endpoint" {
  description = "Endpoint principal."
  value = local.is_cluster ? aws_rds_cluster.this[0].endpoint : aws_db_instance.standalone[0].endpoint
}

output "reader_endpoint" {
  description = "Reader endpoint (solo clúster)."
  value       = local.is_cluster ? aws_rds_cluster.this[0].reader_endpoint : null
}

output "identifier" {
  description = "Identificador de la base de datos o clúster."
  value       = local.is_cluster ? aws_rds_cluster.this[0].id : aws_db_instance.standalone[0].id
}

output "read_replica_ids" {
  description = "IDs de read replicas (si aplica)."
  value       = [for db in aws_db_instance.read_replica : db.id]
}

output "kms_key_arn" {
  description = "ARN de la KMS usada para encriptación (si aplica)."
  value       = local.kms_arn
}
