output "public_ip" {
  description = "The public IP of the bastion host"
  value       = aws_instance.bastion.public_ip
}

output "instance_id" {
  description = "The instance ID of the bastion host"
  value       = aws_instance.bastion.id
}
