provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source = "./modules/vpc"
  
  vpc_name       = "${var.project_name}-vpc"  
  vpc_cidr       = var.vpc_cidr               
  azs            = var.availability_zones     
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs
  
  tags = var.tags
}
module "security" {
  source = "./modules/security"
  
  vpc_id      = module.vpc.vpc_id
  project_name = var.project_name
  
  bastion_ingress_cidr = var.bastion_ingress_cidr
}

module "bastion" {
  source = "./modules/bastion"
  
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.public_subnet_ids[0]
  security_group_id = module.security.bastion_sg_id
  key_name          = var.key_name
  instance_type     = var.bastion_instance_type
  project_name      = var.project_name  
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-bastion"
  })
}

module "alb" {
  source = "./modules/alb"
  
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  security_group_id = module.security.alb_sg_id
  project_name      = var.project_name
  
  tags = var.tags
}

module "asg" {
  source = "./modules/asg"
  
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  security_group_id       = module.security.app_sg_id
  target_group_arns       = [module.alb.target_group_arn]
  key_name                = var.key_name
  instance_type           = var.app_instance_type
  min_size                = var.asg_min_size
  max_size                = var.asg_max_size
  desired_capacity        = var.asg_desired_capacity
  project_name            = var.project_name
  
  tags = var.tags
}

module "database" {
  source = "./modules/database"
  
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  security_group_id    = module.security.db_sg_id
  allocated_storage    = var.db_allocated_storage
  engine               = var.db_engine
  engine_version       = var.db_engine_version
  instance_class       = var.db_instance_class
  name                 = var.db_name
  username             = var.db_username
  password             = var.db_password
  project_name         = var.project_name
  
  tags = var.tags
}