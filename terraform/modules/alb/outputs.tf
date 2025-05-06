output "target_group_arn" {
  description = "ARN du target group pour l'ALB"
  value       = aws_lb_target_group.app.arn
}

output "dns_name" {
  description = "Nom DNS de l'ALB"
  value       = aws_lb.main.dns_name
}

output "alb_id" {
  description = "ID de l'ALB"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN de l'ALB"
  value       = aws_lb.main.arn
}