output "instance_ids" {
  description = "IDs de las instancias."
  value       = [for instance in aws_instance.this : instance.id]
}

output "private_ips" {
  description = "IPs privadas de las instancias."
  value       = [for instance in aws_instance.this : instance.private_ip]
}

output "public_ips" {
  description = "IPs públicas de las instancias."
  value       = [for instance in aws_instance.this : instance.public_ip]
}

output "security_group_id" {
  description = "ID del Security Group."
  value       = aws_security_group.this.id
}

output "instance_profile_name" {
  description = "Nombre del instance profile en uso."
  value       = var.instance_profile_name != null ? var.instance_profile_name : aws_iam_instance_profile.this[0].name
}

output "volume_kms_key_arn" {
  description = "ARN de KMS usada para volúmenes (si aplica)."
  value       = local.kms_arn
}
