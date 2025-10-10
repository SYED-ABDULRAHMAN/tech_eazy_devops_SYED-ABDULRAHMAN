# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "techeazy-devops"
environment  = "production"

# EC2 Configuration - 3 instances across different AZs
instance_count = 3
instance_type  = "t2.micro"

# Network Configuration
vpc_cidr            = "10.0.0.0/16"
public_subnet_cidr  = "10.0.0.0/16"  # Will be auto-divided for multi-AZ

# Security Configuration - Accessible from anywhere
allowed_ssh_cidr  = ["0.0.0.0/0"]  # TODO: Restrict to your IP in production
allowed_http_cidr = ["0.0.0.0/0"]

# Storage Configuration
root_volume_type = "gp3"
root_volume_size = 20

# Key Pair Configuration
create_key_pair   = true
existing_key_name = ""

# Application Configuration
github_repo_url = "https://github.com/Trainings-TechEazy/test-repo-for-devops.git"
app_port        = 80
jar_file_name   = "techeazy-devops-0.0.1-SNAPSHOT.jar"

# Elastic IP Configuration (not needed with ALB)
create_elastic_ip = false
