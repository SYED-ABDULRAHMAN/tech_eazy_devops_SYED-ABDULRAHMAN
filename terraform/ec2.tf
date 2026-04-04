# EC2 Launch Template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-lt-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.app_instance_profile.name
  }

  # Use the same user_data you defined in locals
  user_data = local.user_data

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = var.root_volume_size
      volume_type = var.root_volume_type
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "${var.project_name}-app-instance"
      Environment = var.environment
    }
  }
}
