# Módulo AWS VPC

Este módulo crea una VPC con subnets públicas y privadas, tablas de rutas, IGW y NATGW opcionales, y flow logs a S3 con cifrado KMS.

## Ejemplo de uso

```hcl
provider "aws" {
  region = "eu-west-1"
}

module "vpc" {
  source = "./modules/vpc"

  region   = "eu-west-1"
  vpc_name = "demo-vpc"
  vpc_cidr = "10.0.0.0/16"

  azs = ["a", "b", "c"]

  public_subnets = [
    { az = "a", cidr = "10.0.1.0/24", name = "public-a" },
    { az = "b", cidr = "10.0.2.0/24", name = "public-b" },
    { az = "c", cidr = "10.0.3.0/24", name = "public-c" }
  ]

  private_subnets = [
    { az = "a", cidr = "10.0.101.0/24", name = "private-a" },
    { az = "b", cidr = "10.0.102.0/24", name = "private-b" },
    { az = "c", cidr = "10.0.103.0/24", name = "private-c" }
  ]

  create_igw   = true
  create_natgw = true
  natgw_azs    = ["a", "b"]

  enable_flow_logs          = true
  flow_logs_retention_days  = 30
  flow_logs_traffic_type    = "ALL"
  flow_logs_s3_bucket_name  = null
  flow_logs_kms_key_arn     = null
  dhcp_options_domain_name  = null
  dhcp_options_domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Environment = "dev"
  }
}
```

## Variables

| Nombre | Tipo | Default | Descripción |
| --- | --- | --- | --- |
| `region` | `string` | `"eu-west-1"` | Región usada para construir AZs y el dominio DHCP. |
| `vpc_name` | `string` | n/a | Nombre de la VPC y recursos asociados. |
| `vpc_cidr` | `string` | n/a | CIDR de la VPC. |
| `azs` | `list(string)` | `["a","b","c"]` | AZs en formato sufijo (`a`) o nombre completo (`eu-west-1a`). |
| `public_subnets` | `list(object)` | `[]` | Subnets públicas: `az`, `cidr`, `name`. |
| `private_subnets` | `list(object)` | `[]` | Subnets privadas: `az`, `cidr`, `name`. |
| `enable_dhcp_options` | `bool` | `true` | Crea y asocia DHCP options. |
| `enable_dns_hostnames` | `bool` | `true` | Habilita DNS hostnames en la VPC. |
| `enable_dns_support` | `bool` | `true` | Habilita DNS support en la VPC. |
| `dhcp_options_domain_name` | `string` | `null` | Override del dominio DHCP (por defecto `${region}.compute.internal`). |
| `dhcp_options_domain_name_servers` | `list(string)` | `["AmazonProvidedDNS"]` | Servidores DNS para DHCP. |
| `create_igw` | `bool` | `true` | Crea Internet Gateway. |
| `create_natgw` | `bool` | `false` | Crea NAT Gateway(s). |
| `natgw_azs` | `list(string)` | `[]` | AZs donde crear NATGWs; si está vacío se crea 1 en la primera AZ. |
| `enable_flow_logs` | `bool` | `false` | Habilita VPC flow logs a S3. |
| `flow_logs_kms_key_arn` | `string` | `null` | ARN de KMS existente; si no se pasa, se crea una clave dedicada. |
| `flow_logs_s3_bucket_name` | `string` | `null` | Bucket S3 existente; si no se pasa, se crea `${vpc_name}-flowlogs`. |
| `flow_logs_retention_days` | `number` | `30` | Retención de logs (lifecycle de S3). |
| `flow_logs_traffic_type` | `string` | `"ALL"` | Tipo de tráfico: `ACCEPT`, `REJECT`, `ALL`. |
| `tags` | `map(string)` | `{}` | Tags adicionales. |

## Outputs

| Nombre | Descripción |
| --- | --- |
| `vpc_id` | ID de la VPC. |
| `vpc_cidr` | CIDR de la VPC. |
| `public_subnet_ids` | IDs de subnets públicas. |
| `private_subnet_ids` | IDs de subnets privadas. |
| `igw_id` | ID del Internet Gateway, si existe. |
| `natgw_ids` | IDs de NAT Gateways. |
| `public_route_table_ids` | IDs de route tables públicas. |
| `private_route_table_ids` | IDs de route tables privadas. |
| `route_table_ids` | IDs de todas las route tables. |

## Notas

- Si se pasa un bucket S3 existente para flow logs, este módulo no lo gestiona ni aplica políticas/encriptación; asegúrate de configurarlo previamente.
- Para `azs`, `public_subnets` y `private_subnets`, puedes usar sufijos (`a`) o nombres completos (`eu-west-1a`).
