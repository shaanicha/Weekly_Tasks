provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source = "./modules/vpc"
}

module "ec2" {
  source          = "./modules/ec2"
  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  ami_id          = var.ami_id
  key_name        = var.key_name
}

module "alb" {
  source           = "./modules/alb"
  vpc_id           = module.vpc.vpc_id
  public_subnets   = module.vpc.public_subnets
  target_group_arn = module.ec2.target_group_arn
}

