variable "name_prefix" {
  type        = string
  description = "Prefijo para los recursos."
}

variable "engine" {
  type        = string
  description = "Motor: mysql, postgres, aurora, aurora-mysql, aurora-postgresql."
  default     = "mysql"

  validation {
    condition     = contains(["mysql", "postgres", "aurora", "aurora-mysql", "aurora-postgresql"], var.engine)
    error_message = "engine debe ser mysql, postgres, aurora, aurora-mysql o aurora-postgresql."
  }
}

variable "engine_version" {
  type        = string
  description = "Versión del motor. Si es null, AWS selecciona la recomendada/por defecto."
  default     = null
}

variable "is_cluster" {
  type        = bool
  description = "Si true crea un clúster (solo Aurora)."
  default     = false

  validation {
    condition     = !(var.is_cluster && contains(["mysql", "postgres"], var.engine))
    error_message = "is_cluster solo aplica a Aurora."
  }
}

variable "cluster_instance_count" {
  type        = number
  description = "Número de instancias en el clúster (writer + readers)."
  default     = 2

  validation {
    condition     = var.cluster_instance_count >= 1
    error_message = "cluster_instance_count debe ser >= 1."
  }
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia. Si es null, se usa un tamaño mínimo por motor."
  default     = null
}

variable "db_name" {
  type        = string
  description = "Nombre de la base de datos inicial."
  default     = null
}

variable "username" {
  type        = string
  description = "Usuario maestro."
}

variable "password" {
  type        = string
  description = "Password maestro."
  sensitive   = true
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets para el subnet group."
}

variable "storage_encrypted" {
  type        = bool
  description = "Encripta el almacenamiento."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "ARN de KMS para encriptación. Si es null y storage_encrypted=true, se crea una dedicada."
  default     = null
}

variable "allocated_storage" {
  type        = number
  description = "Almacenamiento (GiB) para standalone."
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Máximo storage autoscaling (GiB) para standalone."
  default     = 100
}

variable "storage_type" {
  type        = string
  description = "Tipo de storage (gp3 recomendado)."
  default     = "gp3"
}

variable "backup_retention_days" {
  type        = number
  description = "Días de retención de backups."
  default     = 7
}

variable "publicly_accessible" {
  type        = bool
  description = "Si la instancia es pública."
  default     = false
}

variable "multi_az" {
  type        = bool
  description = "Multi-AZ para standalone."
  default     = false
}

variable "read_replica_count" {
  type        = number
  description = "Número de read replicas para MySQL/PostgreSQL (standalone)."
  default     = 0

  validation {
    condition     = var.read_replica_count >= 0
    error_message = "read_replica_count debe ser >= 0."
  }
}

variable "ingress_rules" {
  type = list(object({
    cidr_blocks  = optional(list(string))
    source_sg_id = optional(string)
    description  = optional(string)
  }))
  description = "Reglas ingress para el SG."
  default     = []

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      (
        (try(length(rule.cidr_blocks), 0) > 0) ||
        (try(rule.source_sg_id, "") != "")
      )
    ])
    error_message = "Cada regla de ingress debe definir cidr_blocks o source_sg_id."
  }
}

variable "egress_rules" {
  type = list(object({
    cidr_blocks  = optional(list(string))
    source_sg_id = optional(string)
    description  = optional(string)
  }))
  description = "Reglas egress para el SG."
  default = [
    {
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  validation {
    condition = alltrue([
      for rule in var.egress_rules :
      (
        (try(length(rule.cidr_blocks), 0) > 0) ||
        (try(rule.source_sg_id, "") != "")
      )
    ])
    error_message = "Cada regla de egress debe definir cidr_blocks o source_sg_id."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags comunes."
  default     = {}
}
