

output "lb_dns_name" {
  value = aws_lb.app_lb.dns_name
}


# Security Group
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.app_sg.id
}

# VPC Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
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
output "load_balancer_dns" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.app_tg.arn
}


