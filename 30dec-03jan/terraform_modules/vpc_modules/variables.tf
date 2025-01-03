variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr_bits" {
  description = "Number of additional bits to use for public subnet CIDRs"
  default     = 4
}

variable "private_subnet_cidr_bits" {
  description = "Number of additional bits to use for private subnet CIDRs"
  default     = 4
}

variable "availability_zones" {
  description = "List of availability zones to use"
  default     = null # Defaults to all available AZs in the region
}
