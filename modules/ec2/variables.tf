variable "name" {
  type        = string
  description = "Nombre base para la instancia y recursos relacionados."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID donde se lanzan las instancias."
}

variable "instance_count" {
  type        = number
  description = "Número de instancias iguales a crear."
  default     = 1

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count debe ser >= 1."
  }
}

variable "instance_type" {
  type        = string
  description = "Tipo de instancia."
  default     = "t3.micro"
}

variable "market_type" {
  type        = string
  description = "Tipo de mercado: on_demand o spot."
  default     = "on_demand"

  validation {
    condition     = contains(["on_demand", "spot"], var.market_type)
    error_message = "market_type debe ser on_demand o spot."
  }
}

variable "ami_id" {
  type        = string
  description = "AMI ID explícita. Si se define, se usa directamente."
  default     = null
}

variable "ami_lookup" {
  type        = string
  description = "Alias de AMI para buscar la más reciente si ami_id es null."
  default     = "ubuntu-latest"

  validation {
    condition     = contains(["ubuntu-latest", "ubuntu-22.04", "ubuntu-24.04", "amazonlinux2-latest"], var.ami_lookup)
    error_message = "ami_lookup debe ser ubuntu-latest, ubuntu-22.04, ubuntu-24.04 o amazonlinux2-latest."
  }
}

variable "ami_lookup_mode" {
  type        = string
  description = "Modo de búsqueda de AMI: ssm o filter."
  default     = "ssm"

  validation {
    condition     = contains(["ssm", "filter"], var.ami_lookup_mode)
    error_message = "ami_lookup_mode debe ser ssm o filter."
  }
}

variable "ami_ssm_parameter_name" {
  type        = string
  description = "Nombre de parámetro SSM para AMI. Si se define, se usa en lugar de ami_lookup."
  default     = null
}

variable "ami_name_filter_override" {
  type        = string
  description = "Override del filtro name para búsqueda por AMI (modo filter)."
  default     = null
}

variable "ami_owners_override" {
  type        = list(string)
  description = "Override de owners para búsqueda por AMI (modo filter)."
  default     = []
}

variable "volume_sizes" {
  type        = list(number)
  description = "Tamaños de discos (GiB). El primero es root, los siguientes son adicionales."
  default     = []

  validation {
    condition     = length(var.volume_sizes) <= 1 + 11
    error_message = "Se soportan hasta 12 volúmenes (1 root + 11 adicionales)."
  }
}

variable "volume_type" {
  type        = string
  description = "Tipo de volumen EBS."
  default     = "gp3"
}

variable "volume_encrypted" {
  type        = bool
  description = "Si los volúmenes van encriptados."
  default     = false
}

variable "volume_kms_key_arn" {
  type        = string
  description = "ARN de KMS para encriptación de volúmenes. Si es null y volume_encrypted=true, se crea una KMS dedicada."
  default     = null
}

variable "ingress_rules" {
  type = list(object({
    from_port    = number
    to_port      = number
    protocol     = string
    cidr_blocks  = optional(list(string))
    source_sg_id = optional(string)
    description  = optional(string)
  }))
  description = "Reglas de ingress para el SG."
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
    from_port    = number
    to_port      = number
    protocol     = string
    cidr_blocks  = optional(list(string))
    source_sg_id = optional(string)
    description  = optional(string)
  }))
  description = "Reglas de egress para el SG."
  default = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
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

variable "instance_profile_name" {
  type        = string
  description = "Nombre de instance profile existente. Si es null, se crea uno."
  default     = null
}

variable "user_data" {
  type        = string
  description = "User data para las instancias."
  default     = ""
}

variable "enable_metadata_options" {
  type        = bool
  description = "Si true, fuerza IMDSv2; si false, no aplica metadata options."
  default     = true
}

variable "metadata_hop_limit" {
  type        = number
  description = "Hop limit de IMDSv2."
  default     = 1
}

variable "tags" {
  type        = map(string)
  description = "Tags comunes para todos los recursos."
  default     = {}
}

variable "volume_tags" {
  type        = map(string)
  description = "Tags adicionales para volúmenes."
  default     = {}
}
