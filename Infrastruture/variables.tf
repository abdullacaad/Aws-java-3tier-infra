variable "environment" {
  description = "Deployment environment (dev / staging / prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "192.168.0.0/16"
}

variable "public_subnets" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
  default     = ["192.168.1.0/24", "192.168.2.0/24"]
}

variable "private_subnets" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
  default     = ["192.168.3.0/24", "192.168.4.0/24"]
}

variable "db_username" {
  description = "Master username for RDS MySQL"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS MySQL"
  type        = string
  sensitive   = true
}

variable "key_name" {
  description = "Name of EC2 Key Pair for SSH access"
  type        = string
}

variable "app_ami_id" {
  description = "AMI ID for application server instances"
  type        = string
  default     = "ami-0c02fb55956c7d316"  # Amazon Linux 2 us-east-1
}

variable "bastion_ami_id" {
  description = "AMI ID for the bastion host"
  type        = string
  default     = "ami-0c02fb55956c7d316"
}

variable "app_instance_type" {
  description = "EC2 instance type for app servers"
  type        = string
  default     = "t3.micro"
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to bastion host — restrict in production!"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
