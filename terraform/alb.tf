#########################################
# Application Load Balancer (ALB)
#########################################
resource "aws_lb" "app_lb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"

  # Security Group for ALB
  security_groups    = [aws_security_group.lb_sg.id]

  # ✅ Must include at least two subnets in different AZs
  subnets = [
    aws_subnet.public1.id,
    aws_subnet.public2.id
  ]

  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.elb_logs_bucket.bucket
    enabled = true
  }

  tags = {
    Name = "${var.project_name}-alb"
  }
}

#########################################
# Target Group
#########################################
resource "aws_lb_target_group" "app_tg" {
  name     = "${var.project_name}-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-tg"
  }
}

#########################################
# ALB Listener
#########################################
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}
