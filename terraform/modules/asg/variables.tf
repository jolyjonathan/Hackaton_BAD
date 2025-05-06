variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "The IDs of the private subnets"
  type        = list(string)
}

variable "security_group_id" {
  description = "The security group ID for the ASG instances"
  type        = string
}

variable "target_group_arns" {
  description = "The ARNs of the target groups"
  type        = list(string)
}

variable "key_name" {
  description = "The SSH key name"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the ASG instances"
  type        = string
}

variable "min_size" {
  description = "The minimum size of the auto scaling group"
  type        = number
}

variable "max_size" {
  description = "The maximum size of the auto scaling group"
  type        = number
}

variable "desired_capacity" {
  description = "The desired capacity of the auto scaling group"
  type        = number
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to the ASG"
  type        = map(string)
  default     = {}
}