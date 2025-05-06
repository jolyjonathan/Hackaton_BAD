output "bastion_sg_id" {
  description = "ID du groupe de sécurité pour le bastion"
  value       = aws_security_group.bastion.id
}

output "alb_sg_id" {
  description = "ID du groupe de sécurité pour l'ALB"
  value       = aws_security_group.alb.id
}

output "app_sg_id" {
  description = "ID du groupe de sécurité pour l'application"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "ID du groupe de sécurité pour la base de données"
  value       = aws_security_group.db.id
}