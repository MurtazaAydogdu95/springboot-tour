variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
  default     = "springboot"
}

variable "task_container_name" {
  description = "Name of the container within the task definition"
  type        = string
  default     = "springboot"
}

variable "task_image" {
  description = "Docker image for the container within the task definition"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for the container within the task definition"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Memory for the container within the task definition (in MB)"
  type        = number
  default     = 512
}

variable "task_container_port" {
  description = "Port exposed by the container within the task definition"
  type        = number
  default     = 80
}
