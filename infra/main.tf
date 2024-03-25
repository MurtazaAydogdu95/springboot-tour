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

resource "aws_instance" "springboot-tour" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name = aws_key_pair.springboottour.key_name
  provider = aws
  subnet_id = aws_subnet.sub1.id

  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
    host = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y docker.io",
      "sudo usermod -aG docker ubuntu",
      "sudo systemctl start docker",
      "sudo docker pull ${DOCKER_IMAGE_NAME}",
      "sudo docker run -d -p 8000:8000 ${DOCKER_IMAGE_NAME}:latest"
    ]

    vars = {
      DOCKER_IMAGE_NAME = "${var.docker.image_name}"
    }

  }
}
