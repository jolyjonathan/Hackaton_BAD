# modules/database/outputs.tf
output "endpoint" {
  description = "The endpoint of the database"
  value       = aws_db_instance.main.endpoint
}

output "id" {
  description = "The ID of the database"
  value       = aws_db_instance.main.id
}