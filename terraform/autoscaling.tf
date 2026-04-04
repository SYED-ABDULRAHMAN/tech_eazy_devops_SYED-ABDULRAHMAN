resource "aws_autoscaling_group" "app_asg" {
  desired_capacity     = var.instance_count
  max_size             = var.instance_count
  min_size             = var.instance_count
  vpc_zone_identifier  = [aws_subnet.public.id]

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]
force_delete = true

}


