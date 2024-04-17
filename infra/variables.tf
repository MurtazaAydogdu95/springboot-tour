variable "instance_type" {
  description = "EC2 springboot-tour"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "EC2 AMI ID"
  type        = string
  default = "ami-0e5f882be1900e43b"
}

variable "environment" {
  description = "Environment type"
  type        = string
  default     = "development"
}

variable "cidr" {
  default = "10.0.0.0/16"
}

variable "docker_image" {
  default = "murtaza66/springboot:latest"
}
