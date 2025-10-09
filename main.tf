# -------------------------------
# 6. Auto Scaling Group for Worker Nodes
# -------------------------------

resource "aws_launch_template" "eks_launch_template" {
  name_prefix   = "eks-node-lt-"
  image_id      = "ami-02d26659fd82cf299"
  instance_type = "t3.medium"
  key_name      = "windows"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.eks_cluster_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-node"
    }
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              /etc/eks/bootstrap.sh ${aws_eks_cluster.eks_cluster.name}
              EOF
  )
}

resource "aws_autoscaling_group" "eks_asg" {
  name                      = "eks-node-asg"
  desired_capacity          = 2
  max_size                  = 3
  min_size                  = 1
  vpc_zone_identifier       = [aws_subnet.eks_subnet1.id, aws_subnet.eks_subnet2.id]
  health_check_grace_period = 300
  health_check_type         = "EC2"

  launch_template {
    id      = aws_launch_template.eks_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "eks-node"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_eks_cluster.eks_cluster
  ]
}
