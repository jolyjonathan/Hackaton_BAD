# modules/database/variables.tf
variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "The subnet IDs for the database"
  type        = list(string)
}

variable "security_group_id" {
  description = "The security group ID for the database"
  type        = string
}

variable "allocated_storage" {
  description = "The amount of storage to allocate to the database (in GB)"
  type        = number
}

variable "engine" {
  description = "The database engine to use"
  type        = string
}

variable "engine_version" {
  description = "The database engine version to use"
  type        = string
}

variable "instance_class" {
  description = "The instance class for the database"
  type        = string
}

variable "name" {
  description = "The name of the database"
  type        = string
}

variable "username" {
  description = "The username for the database"
  type        = string
  sensitive   = true
}

variable "password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to the database resources"
  type        = map(string)
  default     = {}
}