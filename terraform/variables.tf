variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
  
  validation {
    condition = contains([
      "t3.micro", "t3.small", "t3.medium", "t3.large",
      "t2.micro", "t2.small", "t2.medium", "t2.large"
    ], var.instance_type)
    error_message = "Instance type must be a valid t2 or t3 instance type."
  }
}

# Storage Configuration
variable "root_volume_type" {
  description = "Root volume type"
  type        = string
  default     = "gp3"
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region where resources will be created"
}

variable "project_name" {
  type        = string
  description = "Project name used for naming resources"
}


# Key Pair Configuration
variable "create_key_pair" {
  description = "Whether to create a new key pair or use an existing one"
  type        = bool
  default     = true
}

variable "existing_key_name" {
  description = "Name of existing key pair (used if create_key_pair is false)"
  type        = string
  default     = ""
}

# Application Configuration
variable "github_repo_url" {
  description = "GitHub repository URL for the application"
  type        = string
  default     = "https://github.com/Trainings-TechEazy/test-repo-for-devops.git"
}

variable "app_port" {
  description = "Port on which the application will run"
  type        = number
  default     = 8080
}

# Elastic IP Configuration
variable "create_elastic_ip" {
  description = "Whether to create and assign an Elastic IP"
  type        = bool
  default     = false
}
# Networking Configuration
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Environment Tagging
variable "environment" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
  default     = "dev"
}

# Security Group Access
variable "allowed_ssh_cidr" {
  description = "CIDR blocks allowed to access SSH (port 22)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_http_cidr" {
  description = "CIDR blocks allowed to access HTTP/HTTPS (ports 80, 443, 8080)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
variable "s3_bucket_name" {
  description = "Name of the S3 bucket for logs"
  type        = string
  default     = "my-app-logs-bucket-142825327"
}


variable "app_jar_bucket_name" {
  description = "S3 bucket name to store the JAR"
  type        = string
  default     = "app-jar-bucket-13131435"
}

variable "elb_logs_bucket_name" {
  description = "S3 bucket for storing ALB logs"
  type        = string
  default     = "elb-logs-bucket-3513564634"
}

variable "instance_count" {
  description = "Number of EC2 instances behind the LB"
  type        = number
  default     = 2
}
