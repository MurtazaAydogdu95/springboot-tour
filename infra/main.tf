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

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2b"
  map_public_ip_on_launch = true
}

resource "aws_key_pair" "springboottour" {
  key_name = "terraform-demo"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_ecr_repository" "springboot_repository" {
  name = "springboot-repository"
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

resource "aws_eks_cluster" "springboot" {
  name     = "springboot"
  role_arn = aws_iam_role.eks-role.arn

  vpc_config {
    subnet_ids = [
      aws_subnet.sub1.id,
      aws_subnet.sub2.id
    ]
  }
}

resource "aws_iam_role" "eks-role" {
  name = "example-eks-role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "example" {
  role       = aws_iam_role.eks-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "example_node_groups" {
  role       = aws_iam_role.eks-role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_policy" "eks_cni_policy" {
  name        = "MyEKSCNIPolicy"
  description = "Custom policy for Amazon EKS CNI"
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:ListClusters",
        "eks:ListFargateProfiles",
        "eks:ListUpdates",
        "eks:ListAddons",
        "eks:AccessKubernetesApi",
        "eks:ListTagsForResource"
      ],
      "Resource": "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "example_cni" {
  role       = aws_iam_role.eks-role.name
  policy_arn = aws_iam_policy.eks_cni_policy.arn
}
