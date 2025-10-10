# ALB Information
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "alb_url" {
  description = "URL to access the application via ALB"
  value       = "http://${aws_lb.app_alb.dns_name}"
}

output "alb_zone_id" {
  description = "Zone ID of the ALB (for Route53)"
  value       = aws_lb.app_alb.zone_id
}

# EC2 Instances Information
output "instance_ids" {
  description = "IDs of all EC2 instances"
  value       = aws_instance.app_servers[*].id
}

output "instance_public_ips" {
  description = "Public IP addresses of all EC2 instances"
  value       = aws_instance.app_servers[*].public_ip
}

output "instance_private_ips" {
  description = "Private IP addresses of all EC2 instances"
  value       = aws_instance.app_servers[*].private_ip
}

output "instance_availability_zones" {
  description = "Availability zones of all EC2 instances"
  value       = aws_instance.app_servers[*].availability_zone
}

# S3 Buckets
output "s3_jar_bucket" {
  description = "Name of the S3 bucket for application JARs"
  value       = aws_s3_bucket.app_jars.id
}

output "s3_logs_bucket" {
  description = "Name of the S3 bucket for application logs"
  value       = aws_s3_bucket.app_logs.id
}

output "s3_alb_logs_bucket" {
  description = "Name of the S3 bucket for ALB access logs"
  value       = aws_s3_bucket.alb_logs.id
}

# SSH Connection Commands
output "ssh_commands" {
  description = "SSH commands for all instances"
  value = [
    for idx, instance in aws_instance.app_servers : 
    "ssh -i ${var.project_name}-key.pem ubuntu@${instance.public_ip}  # Instance ${idx}"
  ]
}

# Security Groups
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "app_security_group_id" {
  description = "ID of the application security group"
  value       = aws_security_group.app_sg.id
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "IDs of all public subnets"
  value       = aws_subnet.public[*].id
}

# Deployment Instructions
output "deployment_instructions" {
  description = "Instructions for deploying the application"
  value = <<-EOT
  
  ===== DEPLOYMENT INSTRUCTIONS =====
  
  1. Upload JAR to S3:
     aws s3 cp target/${var.jar_file_name} s3://${aws_s3_bucket.app_jars.id}/
  
  2. Access Application:
     URL: http://${aws_lb.app_alb.dns_name}
  
  3. Monitor Auto-Updates:
     - Instances check S3 every 5 minutes
     - Updates happen automatically
     - Logs uploaded to: s3://${aws_s3_bucket.app_logs.id}/instance-{0,1,2}/
  
  4. Verify Round-Robin Load Distribution:
     curl -s http://${aws_lb.app_alb.dns_name} -I | grep X-Instance
     (Run multiple times to see different instances)
  
  5. Check ALB Logs for Traffic Distribution:
     aws s3 ls s3://${aws_s3_bucket.alb_logs.id}/alb-logs/ --recursive
  
  6. SSH to Instances:
     ${join("\n     ", [for idx, instance in aws_instance.app_servers : "ssh -i ${var.project_name}-key.pem ubuntu@${instance.public_ip}  # Instance ${idx}"])}
  
  7. Monitor Application Status:
     systemctl status app
     journalctl -u app -f
  
  8. Check Auto-Update Timer:
     systemctl status app-auto-update.timer
     journalctl -u app-auto-update -f
  
  ===================================
  EOT
}

# Key Pair Information
output "key_pair_name" {
  description = "Name of the key pair"
  value       = var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_name
}

output "private_key_file" {
  description = "Path to the private key file (if created)"
  value       = var.create_key_pair ? "${var.project_name}-key.pem" : "Using existing key pair"
}

# Target Group Information
output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app_tg.arn
}

# Instance Count
output "total_instances" {
  description = "Total number of EC2 instances deployed"
  value       = var.instance_count
}
