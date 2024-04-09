provider "aws" {
  region = "eu-west-2"
}

resource "aws_vpc" "myvpc" {
  cidr_block = var.cidr
}

resource "aws_key_pair" "springboottour" {
  key_name   = "terraform-demo"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_ecr_repository" "springboot_repository" {
  name                 = "springboot-repository"
  image_tag_mutability = "MUTABLE"
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

locals {
  cluster_name = "springboot"
  role_name = "springboot-role"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "springboot-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-2a", "eu-west-2b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Environment = "dev"
  }

  single_nat_gateway = true
  one_nat_gateway_per_az = false

  map_public_ip_on_launch = true
}

resource "aws_security_group" "eks_cluster_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "eks_role" {
  name               = local.role_name
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "eks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_eks_cluster" "eks_cluster" {

  vpc_config {
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
    subnet_ids         = module.vpc.public_subnets
  }
  name     = local.cluster_name
  role_arn = aws_iam_role.eks_role.arn
}


resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name = "/aws/eks/${aws_eks_cluster.eks_cluster.name}"
}

data "aws_iam_policy_document" "eks_logs_policy" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      aws_cloudwatch_log_group.eks_cluster_logs.arn
    ]
  }
}

resource "aws_iam_policy" "eks_logs_policy" {
  name        = "eks_cluster_logs_policy"
  description = "IAM policy for EKS cluster logs"
  policy      = data.aws_iam_policy_document.eks_logs_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_logs_policy_attachment" {
  depends_on = [aws_eks_cluster.eks_cluster]
  role       = aws_iam_role.eks_role.name
  policy_arn = aws_iam_policy.eks_logs_policy.arn
}
