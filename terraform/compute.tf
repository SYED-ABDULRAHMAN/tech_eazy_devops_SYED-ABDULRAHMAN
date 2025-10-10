# Data source for getting the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create Key Pair
resource "tls_private_key" "app_key" {
  count     = var.create_key_pair ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "app_key" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = "${var.project_name}-key"
  public_key = tls_private_key.app_key[0].public_key_openssh

  tags = {
    Name        = "${var.project_name}-key"
    Environment = var.environment
  }
}

# Save private key to local file
resource "local_file" "private_key" {
  count           = var.create_key_pair ? 1 : 0
  content         = tls_private_key.app_key[0].private_key_pem
  filename        = "${var.project_name}-key.pem"
  file_permission = "0600"
}

# User data script for application setup
locals {
  user_data = templatefile("${path.module}/user_data.sh", {
    github_repo_url    = var.github_repo_url
    app_port           = var.app_port
    s3_jar_bucket      = aws_s3_bucket.app_jars.id
    s3_logs_bucket     = aws_s3_bucket.app_logs.id
    aws_region         = var.aws_region
    jar_file_name      = var.jar_file_name
    instance_id_token  = "INSTANCE_ID_PLACEHOLDER"
    auto_update_script_content = file("${path.module}/scripts/auto-update.sh")

  })
}

# Create multiple EC2 instances across different AZs
resource "aws_instance" "app_servers" {
  count = var.instance_count

  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  
  # Distribute instances across different AZs
  subnet_id = element(aws_subnet.public[*].id, count.index)
  
  # User data with instance-specific configuration
  user_data = base64encode(replace(local.user_data, "INSTANCE_ID_PLACEHOLDER", count.index))
  
  iam_instance_profile = aws_iam_instance_profile.app_instance_profile.name

  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = {
    Name        = "${var.project_name}-app-server-${count.index + 1}"
    Environment = var.environment
    Instance    = count.index
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_iam_instance_profile.app_instance_profile,
    aws_s3_bucket.app_jars,
    aws_s3_bucket.app_logs
  ]
}

# Create Elastic IPs if needed
resource "aws_eip" "app_eips" {
  count      = var.create_elastic_ip ? var.instance_count : 0
  instance   = aws_instance.app_servers[count.index].id
  domain     = "vpc"
  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.project_name}-eip-${count.index + 1}"
    Environment = var.environment
  }
}
