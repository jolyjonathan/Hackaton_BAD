output "vpc_id" {
  description = "ID du VPC créé"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Liste des IDs des sous-réseaux publics"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Liste des IDs des sous-réseaux privés"
  value       = aws_subnet.private[*].id
}