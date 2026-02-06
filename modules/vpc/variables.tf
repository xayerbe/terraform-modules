variable "region" {
  type        = string
  description = "AWS region used to build AZ names and DHCP domain."
  default     = "eu-west-1"
}

variable "vpc_name" {
  type        = string
  description = "Name for the VPC and related resources."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "azs" {
  type        = list(string)
  description = "Availability zones suffixes or full names. Defaults to a,b,c."
  default     = ["a", "b", "c"]
}

variable "public_subnets" {
  type = list(object({
    az   = string
    cidr = string
    name = string
  }))
  description = "Public subnets with AZ (suffix or full), CIDR, and Name."
  default     = []
}

variable "private_subnets" {
  type = list(object({
    az   = string
    cidr = string
    name = string
  }))
  description = "Private subnets with AZ (suffix or full), CIDR, and Name."
  default     = []
}

variable "enable_dhcp_options" {
  type        = bool
  description = "Whether to create and associate DHCP options."
  default     = true
}

variable "enable_dns_hostnames" {
  type        = bool
  description = "Enable DNS hostnames in the VPC."
  default     = true
}

variable "enable_dns_support" {
  type        = bool
  description = "Enable DNS support in the VPC."
  default     = true
}

variable "dhcp_options_domain_name" {
  type        = string
  description = "Override DHCP domain name. Default uses region.compute.internal."
  default     = null
}

variable "dhcp_options_domain_name_servers" {
  type        = list(string)
  description = "DHCP domain name servers. Default uses AmazonProvidedDNS."
  default     = ["AmazonProvidedDNS"]
}

variable "create_igw" {
  type        = bool
  description = "Whether to create an Internet Gateway."
  default     = true
}

variable "create_natgw" {
  type        = bool
  description = "Whether to create NAT Gateway(s)."
  default     = false

  validation {
    condition     = !(var.create_natgw && !var.create_igw)
    error_message = "create_natgw requires create_igw = true."
  }
}

variable "natgw_azs" {
  type        = list(string)
  description = "AZs (suffix or full) where NAT GWs should be created. If empty, one NAT GW is created in the first AZ."
  default     = []
}

variable "enable_flow_logs" {
  type        = bool
  description = "Whether to enable VPC flow logs to S3."
  default     = false
}

variable "flow_logs_kms_key_arn" {
  type        = string
  description = "Existing KMS key ARN for flow logs. If null and flow logs enabled, a dedicated key is created."
  default     = null
}

variable "flow_logs_s3_bucket_name" {
  type        = string
  description = "Existing S3 bucket name for flow logs. If null and flow logs enabled, a bucket is created."
  default     = null
}

variable "flow_logs_retention_days" {
  type        = number
  description = "Retention days for flow logs (S3 lifecycle expiration)."
  default     = 30
}

variable "flow_logs_traffic_type" {
  type        = string
  description = "Traffic type to capture for flow logs."
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], upper(var.flow_logs_traffic_type))
    error_message = "flow_logs_traffic_type must be ACCEPT, REJECT, or ALL."
  }
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources."
  default     = {}
}
