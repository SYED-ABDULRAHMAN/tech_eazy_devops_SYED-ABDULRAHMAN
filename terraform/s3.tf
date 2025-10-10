# S3 bucket for application JAR files
resource "aws_s3_bucket" "app_jars" {
  bucket        = "${var.project_name}-app-jars-${random_string.bucket_suffix.result}"
  force_destroy = false

  tags = {
    Name        = "${var.project_name}-app-jars"
    Environment = var.environment
    Purpose     = "Application JAR storage"
  }
}

# Enable versioning for JAR bucket
resource "aws_s3_bucket_versioning" "app_jars_versioning" {
  bucket = aws_s3_bucket.app_jars.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access for JAR bucket
resource "aws_s3_bucket_public_access_block" "app_jars_public_block" {
  bucket = aws_s3_bucket.app_jars.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket for application logs (instance-specific)
resource "aws_s3_bucket" "app_logs" {
  bucket        = "${var.project_name}-app-logs-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-app-logs"
    Environment = var.environment
    Purpose     = "Application logs storage"
  }
}

# Lifecycle policy for application logs (7 days retention)
resource "aws_s3_bucket_lifecycle_configuration" "app_logs_lifecycle" {
  bucket = aws_s3_bucket.app_logs.id

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {}
    
    expiration {
      days = 7
    }
  }
}

# S3 bucket for ALB access logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-alb-logs-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-alb-logs"
    Environment = var.environment
    Purpose     = "ALB access logs"
  }
}

# Lifecycle policy for ALB logs (7 days retention)
resource "aws_s3_bucket_lifecycle_configuration" "alb_logs_lifecycle" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "delete-old-alb-logs"
    status = "Enabled"

    filter {}
    
    expiration {
      days = 7
    }
  }
}

# Bucket policy to allow ALB to write access logs
resource "aws_s3_bucket_policy" "alb_logs_policy" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Sid    = "AWSLogDeliveryAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "elasticloadbalancing.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# Random string for unique bucket names
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Data source for AWS account ID
data "aws_caller_identity" "current" {}
