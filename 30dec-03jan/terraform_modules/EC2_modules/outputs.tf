# modules/ec2/outputs.tf
output "target_group_arn" {
  value = aws_lb_target_group.example.arn
}

output "instance_ids" {
  value = aws_instance.app[*].id
}

# If you need to output the security group ID, reference it through the module
output "security_group_id" {
  value = module.security_group.ec2_security_group_id
}
