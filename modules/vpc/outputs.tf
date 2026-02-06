output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "igw_id" {
  description = "Internet Gateway ID, if created."
  value       = var.create_igw ? aws_internet_gateway.this[0].id : null
}

output "natgw_ids" {
  description = "NAT Gateway IDs."
  value       = [for natgw in aws_nat_gateway.this : natgw.id]
}

output "public_route_table_ids" {
  description = "Public route table IDs."
  value       = [for rt in aws_route_table.public : rt.id]
}

output "private_route_table_ids" {
  description = "Private route table IDs."
  value       = [for rt in aws_route_table.private : rt.id]
}

output "route_table_ids" {
  description = "All route table IDs."
  value = concat(
    [for rt in aws_route_table.public : rt.id],
    [for rt in aws_route_table.private : rt.id]
  )
}
