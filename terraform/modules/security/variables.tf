variable "vpc_id" {
  description = "ID du VPC"
  type        = string
}

variable "project_name" {
  description = "Nom du projet"
  type        = string
}

variable "bastion_ingress_cidr" {
  description = "Liste des CIDR autorisés à accéder au bastion"
  type        = list(string)
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}