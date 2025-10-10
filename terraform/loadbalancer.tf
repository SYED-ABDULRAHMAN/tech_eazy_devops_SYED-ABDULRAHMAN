# Application Load Balancer
resource "aws_lb" "app_alb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  # Access logs configuration
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb-logs"
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }

  depends_on = [
    aws_s3_bucket_policy.alb_logs_policy
  ]
}

# Target Group for EC2 instances
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.project_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  # Health check configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  # Deregistration delay (time to wait before removing instance)
  deregistration_delay = 30

  # Stickiness disabled for true round-robin
  stickiness {
    type    = "lb_cookie"
    enabled = false
  }

  tags = {
    Name        = "${var.project_name}-target-group"
    Environment = var.environment
  }
}

# Register EC2 instances with target group
resource "aws_lb_target_group_attachment" "app_targets" {
  count = var.instance_count

  target_group_arn = aws_lb_target_group.app_tg.arn
  target_id        = aws_instance.app_servers[count.index].id
  port             = var.app_port
}

# ALB Listener for HTTP traffic
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  tags = {
    Name        = "${var.project_name}-listener"
    Environment = var.environment
  }
}
