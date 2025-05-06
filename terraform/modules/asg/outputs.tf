output "asg_id" {
  description = "The ID of the auto scaling group"
  value       = aws_autoscaling_group.app.id
}

output "asg_name" {
  description = "The name of the auto scaling group"
  value       = aws_autoscaling_group.app.name
}

output "launch_template_id" {
  description = "The ID of the launch template"
  value       = aws_launch_template.app.id
}