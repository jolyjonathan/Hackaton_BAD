variable "aws_region" {
  description = "The AWS region to deploy to"
  type        = string
  default     = "eu-west-3"  # Paris
}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "greenshop"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "The availability zones to deploy to"
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b"]
}

variable "private_subnet_cidrs" {
  description = "The CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "public_subnet_cidrs" {
  description = "The CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "bastion_ingress_cidr" {
  description = "CIDR blocks allowed for SSH to bastion"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restreindre dans un environnement de production
}

variable "key_name" {
  description = "The name of the SSH key pair to use"
  type        = string
  default     = "greenshop-key"
}

variable "bastion_instance_type" {
  description = "The instance type to use for the bastion host"
  type        = string
  default     = "t2.micro"
}

variable "app_instance_type" {
  description = "The instance type to use for the application"
  type        = string
  default     = "t2.small"
}

variable "asg_min_size" {
  description = "The minimum size of the auto scaling group"
  type        = number
  default     = 3
}

variable "asg_max_size" {
  description = "The maximum size of the auto scaling group"
  type        = number
  default     = 5
}

variable "asg_desired_capacity" {
  description = "The desired capacity of the auto scaling group"
  type        = number
  default     = 2
}

variable "db_allocated_storage" {
  description = "The amount of storage to allocate to the database (in GB)"
  type        = number
  default     = 20
}

variable "db_engine" {
  description = "The database engine to use"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "The database engine version to use"
  type        = string
  default     = "8.0"
}

variable "db_instance_class" {
  description = "The instance class for the database"
  type        = string
  default     = "db.t3.small"
}

variable "db_name" {
  description = "The name of the database"
  type        = string
  default     = "greenshop"
}

variable "db_username" {
  description = "The username for the database"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "A map of tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "greenshop"
    Terraform   = "true"
  }
}