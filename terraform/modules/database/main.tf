# modules/database/main.tf
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = var.subnet_ids
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "main" {
  identifier             = "${var.project_name}-db"
  allocated_storage      = var.allocated_storage
  engine                 = var.engine
  engine_version         = var.engine_version
  instance_class         = var.instance_class
  db_name                = var.name
  username               = var.username
  password               = var.password
  #parameter_group_name   = "default.${var.engine}${var.engine_version}"
  #db_subnet_group_name   = aws_db_subnet_group.main.name
  #vpc_security_group_ids = [var.security_group_id]
  skip_final_snapshot    = true
  multi_az               = true
  storage_encrypted      = true
  
  tags = merge(var.tags, {
    Name = "${var.project_name}-db"
  })
}