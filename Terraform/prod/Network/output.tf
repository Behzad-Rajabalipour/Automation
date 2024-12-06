# it only can get output.tf of networkmodule
output "public_subnet_ids" {
  value = module.vpc-dev.public_subnet_ids # error => value = aws_subnet.public_subnet[*].id
}

# it only can get output.tf of networkmodule
output "public_subnet_cidrs" {
  value = module.vpc-dev.public_subnet_cidrs # error => value = aws_subnet.public_subnet[*].id
}

# it only can get output.tf of networkmodule
output "private_subnet_ids" {
  value = module.vpc-dev.private_subnet_ids # error => value = aws_subnet.public_subnet[*].id
}

output "public_route_table_id" {
  value = module.vpc-dev.public_route_table.id
}

output "vpc_id" {
  value = module.vpc-dev.vpc_id # error => value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = module.vpc-dev.vpc_cidr
}

output "target_group_arn" {
  value = module.vpc-dev.target_group.arn
}

output "ALB_SG_id" {
  value = module.vpc-dev.ALB_SG_id
}
