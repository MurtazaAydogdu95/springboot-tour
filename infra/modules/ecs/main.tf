variable "security_groups" {}

variable "subnets" {}


resource "aws_ecs_cluster" "ecs_cluster" {
  name = var.cluster_name
}

resource "aws_ecs_service" "service" {
  name                   = "app_services"
  cluster                = aws_ecs_cluster.ecs_cluster.arn
  launch_type            = "FARGATE"
  enable_execute_command = true

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  task_definition                    = aws_ecs_task_definition.ecs_task_definition.arn

  network_configuration {
    assign_public_ip = true
    security_groups  = [var.security_groups]
    subnets          = [var.subnets]
  }

}

resource "aws_ecs_task_definition" "ecs_task_definition" {
  container_definitions = jsonencode([
    {
      name   = var.task_container_name
      image  = "334372355104.dkr.ecr.us-east-1.amazonaws.com/cnap-springboot-ecr"
      cpu    = var.task_cpu
      memory = var.task_memory
      portMappings = [
        {
          containerPort = var.task_container_port
          hostPort      = var.task_container_port
          protocol      = "tcp"
        }
      ]
    }
  ])
  family                   = "ecs-task"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  task_role_arn            = "arn:aws:iam::334372355104:role/ecsTaskExecutionRole"
  execution_role_arn       = "arn:aws:iam::334372355104:role/ecsTaskExecutionRole"
}
