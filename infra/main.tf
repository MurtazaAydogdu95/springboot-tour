# Configure the AWS Provider
provider "aws" {
  region = var.region
}

#Retrieve the list of AZs in the current AWS region
data "aws_availability_zones" "available" {}
data "aws_region" "current" {}

module "vpc" {
  source = "./modules/vpc"
}

module "ecr" {
  source = "./modules/ecr"
}

module "ecs" {
  source     = "./modules/ecs"
  task_image = "334372355104.dkr.ecr.us-east-1.amazonaws.com/cnap-springboot-ecr"
  security_groups = module.vpc.sg
  subnets = module.vpc.subnet
}



