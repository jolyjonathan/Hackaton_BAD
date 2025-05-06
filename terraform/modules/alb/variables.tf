variable "vpc_id" {
  description = "L'ID du VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "Liste des ID de sous-réseaux publics pour l'ALB"
  type        = list(string)
}

variable "security_group_id" {
  description = "L'ID du groupe de sécurité pour l'ALB"
  type        = string
}

variable "project_name" {
  description = "Le nom du projet"
  type        = string
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}