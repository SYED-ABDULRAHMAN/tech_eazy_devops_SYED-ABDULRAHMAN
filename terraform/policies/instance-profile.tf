# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_app_role" {
  name = "${var.project_name}-ec2-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ec2-role"
    Environment = var.environment
  }
}

# Attach EC2 S3 JAR read policy to role
resource "aws_iam_role_policy_attachment" "ec2_jar_read_attach" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.ec2_s3_jar_read.arn
}

# Attach EC2 S3 logs write policy to role
resource "aws_iam_role_policy_attachment" "ec2_logs_write_attach" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = aws_iam_policy.ec2_s3_logs_write.arn
}

# Attach CloudWatch logs policy for monitoring
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_attach" {
  role       = aws_iam_role.ec2_app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Create instance profile for EC2
resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_app_role.name

  tags = {
    Name        = "${var.project_name}-instance-profile"
    Environment = var.environment
  }
}
