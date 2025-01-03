variable "vpc_id" {
  description = "VPC ID where the ALB will be created"
  type        = string
}

variable "public_subnets" {
  description = "List of public subnet IDs for the ALB"
  type        = list(string)
}

variable "target_group_arn" {
  description = "The ARN of the target group created in the EC2 module"
  type        = string
}
