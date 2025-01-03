# Reference the security group module
module "security_group" {
  source = "../security_group"
  vpc_id = var.vpc_id
}

# EC2 Instances
resource "aws_instance" "app" {
  count         = 2
  ami           = var.ami_id
  instance_type = "t2.micro"
  key_name      = var.key_name
  subnet_id     = element(var.private_subnets, count.index)
  
  # Updated to use the correct output reference
  vpc_security_group_ids = [module.security_group.ec2_security_group_id]
  
  tags = {
    Name = "app-instance-${count.index}"
  }
}

# Target Group for ALB
resource "aws_lb_target_group" "example" {
  name        = "app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "app-target-group"
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "example" {
  count            = length(aws_instance.app)
  target_group_arn = aws_lb_target_group.example.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}
