provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true
}

resource "aws_key_pair" "springboottour" {
  key_name = "terraform-demo"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_ecr_repository" "springboot_repository" {
  name = "springboot-repository"
}

output "ecr_repository_url" {
  value = aws_ecr_repository.springboot_repository.repository_url
}
