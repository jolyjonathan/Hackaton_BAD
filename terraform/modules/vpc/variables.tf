variable "vpc_name" {
  description = "Nom du VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block du VPC"
  type        = string
}

variable "azs" {
  description = "Zones de disponibilité à utiliser"
  type        = list(string)
}

variable "private_subnets" {
  description = "Liste des CIDR blocks pour les sous-réseaux privés"
  type        = list(string)
}

variable "public_subnets" {
  description = "Liste des CIDR blocks pour les sous-réseaux publics"
  type        = list(string)
}

variable "tags" {
  description = "Tags à appliquer aux ressources"
  type        = map(string)
  default     = {}
}