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

resource "aws_ecr_repository_policy" "ecr_policy" {
  repository = aws_ecr_repository.springboot_repository.name

  policy = jsonencode({
    "Version": "2008-10-17",
    "Statement": [
      {
        "Sid": "Allow-Docker-Push-Pull",
        "Effect": "Allow",
        "Principal": "*",
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage"
        ]
      }
    ]
  })
}
