variable "vpc_id" {
  description = "VPC ID for EC2 instances"
}

variable "private_subnets" {
  description = "Private subnets for EC2 instances"
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
}

variable "key_name" {
  description = "Key pair name for EC2 instances"
}
