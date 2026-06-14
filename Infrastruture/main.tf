# ==============================================================
# CloudStride — AWS 3-Tier Infrastructure
# Author: Muhammad Abdullah Saad
# Email:  abdullahsaadofficial@gmail.com
# GitHub: https://github.com/abdullahsaad
# ==============================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPC Module ────────────────────────────────────────────────
module "vpc" {
  source          = "./modules/vpc"
  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  aws_region      = var.aws_region
}

# ── Security Groups Module ────────────────────────────────────
module "security" {
  source                  = "./modules/security"
  environment             = var.environment
  vpc_id                  = module.vpc.vpc_id
  allowed_ssh_cidr_blocks = var.allowed_ssh_cidr_blocks
}

# ── RDS MySQL (Data Tier) ─────────────────────────────────────
resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = module.vpc.private_subnet_ids

  tags = {
    Name        = "${var.environment}-db-subnet-group"
    Environment = var.environment
    ManagedBy   = "Terraform"
    Author      = "Muhammad Abdullah Saad"
  }
}

resource "aws_db_instance" "mysql" {
  identifier             = "${var.environment}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  db_name                = "cloudstridedb"
  username               = var.db_username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [module.security.db_security_group_id]
  multi_az               = var.environment == "prod" ? true : false
  skip_final_snapshot    = var.environment == "prod" ? false : true
  backup_retention_period = 7
  deletion_protection    = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.environment}-mysql"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# ── Application Load Balancer ─────────────────────────────────
resource "aws_lb" "app" {
  name               = "${var.environment}-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [module.security.alb_security_group_id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  tags = {
    Name        = "${var.environment}-app-alb"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "${var.environment}-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ── Launch Template (App Tier) ────────────────────────────────
resource "aws_launch_template" "app" {
  name_prefix   = "${var.environment}-app-"
  image_id      = var.app_ami_id
  instance_type = var.app_instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [module.security.app_security_group_id]

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y java-11-amazon-corretto tomcat
    systemctl enable tomcat
    systemctl start tomcat
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.environment}-app-server"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ── Auto Scaling Group ────────────────────────────────────────
resource "aws_autoscaling_group" "app" {
  name                = "${var.environment}-app-asg"
  vpc_zone_identifier = module.vpc.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.environment}-app-server"
    propagate_at_launch = true
  }
}

# ── Bastion Host ──────────────────────────────────────────────
resource "aws_instance" "bastion" {
  ami                         = var.bastion_ami_id
  instance_type               = "t3.micro"
  subnet_id                   = module.vpc.public_subnet_ids[0]
  vpc_security_group_ids      = [module.security.bastion_security_group_id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = {
    Name        = "${var.environment}-bastion"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
