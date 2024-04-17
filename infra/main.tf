provider "aws" {
  region = "eu-west-2"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
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
  role_name    = "springboot-role"
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
    Terraform   = "true"
    Environment = "dev"
  }

  single_nat_gateway     = true
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

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_cluster_certificate_authority_data" {
  value = aws_eks_cluster.eks_cluster.certificate_authority[0].data
}

resource "aws_instance" "springboot" {
  count         = 1
  ami           = "ami-0b9932f4918a00c4f"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.springboottour.key_name
  subnet_id     = module.vpc.private_subnets[0]
  tags = {
    Name = "eks-worker-${count.index}"
  }
}

resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name = "/aws/eks/${aws_eks_cluster.eks_cluster.name}"
}

data "aws_iam_policy_document" "eks_logs_policy" {
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"]
    resources = [aws_cloudwatch_log_group.eks_cluster_logs.arn]
  }
}

resource "aws_iam_policy" "eks_logs_policy" {
  name        = "eks_cluster_logs_policy"
  description = "IAM policy for EKS cluster logs"
  policy      = data.aws_iam_policy_document.eks_logs_policy.json
}

resource "aws_iam_role_policy_attachment" "eks_logs_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_policy" "eks_policy" {
  name        = "eks-cluster-policy"
  description = "Policy for Amazon EKS cluster"

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListNodegroups", "eks:ListClusters", "eks:CreateCluster", "eks:DeleteCluster", "eks:UpdateClusterConfig", "eks:TagResource", "eks:UntagResource", "eks:DescribeUpdate", "eks:UpdateClusterVersion"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = aws_iam_policy.eks_policy.arn
}

resource "aws_iam_role_policy_attachment" "eks_additional_policies_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"  # Required policy for worker nodes
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"        # Required policy for networking
}

resource "aws_iam_role_policy_attachment" "eks_ec2_policy_attachment" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"  # Required policy for pulling images from ECR
}

# Kubernetes Deployment resource for Spring Boot application
resource "kubernetes_deployment" "springboot_deployment" {
  metadata {
    name = "springboot-deployment"
    labels = {
      app = "springboot"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "springboot"
      }
    }

    template {
      metadata {
        labels = {
          app = "springboot"
        }
      }

      spec {
        container {
          image = "${aws_ecr_repository.springboot_repository.repository_url}:latest"
          name  = "springboot"
          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

# Kubernetes Service resource for exposing Spring Boot application
resource "kubernetes_service" "springboot_service" {
  metadata {
    name = "springboot-service"
  }

  spec {
    selector = {
      app = "springboot"
    }

    port {
      protocol   = "TCP"
      port       = 8080
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}
