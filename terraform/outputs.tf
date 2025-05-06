output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "bastion_public_ip" {
  description = "The public IP of the bastion host"
  value       = module.bastion.public_ip
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = module.alb.dns_name
}

output "db_endpoint" {
  description = "The endpoint of the database"
  value       = module.database.endpoint
}