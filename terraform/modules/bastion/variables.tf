variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID for the bastion host"
  type        = string
}

variable "security_group_id" {
  description = "The security group ID for the bastion host"
  type        = string
}

variable "key_name" {
  description = "The SSH key name"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the bastion host"
  type        = string
  default     = "t2.micro"
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to the bastion host"
  type        = map(string)
  default     = {}
}
