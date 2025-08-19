# variables.tf

# Configuração do provedor AWS
provider "aws" {
  region = "us-east-1" # Você pode alterar a região conforme necessário
}

# ----------------------------------------
# Variáveis
# ----------------------------------------

variable "unique_id" {
  description = "A unique identifier for resources in this stack"
  type        = string
  default     = "streamlit-example"
}

variable "vpc_cidr" {
  description = "IP range (CIDR notation) for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "IP range (CIDR notation) for the public subnet in the first Availability Zone"
  type        = string
  default     = "10.0.0.0/24"
}

variable "public_subnet_b_cidr" {
  description = "IP range (CIDR notation) for the public subnet in the second Availability Zone"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_a_cidr" {
  description = "IP range (CIDR notation) for the private subnet in the first Availability Zone"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_b_cidr" {
  description = "IP range (CIDR notation) for the private subnet in the second Availability Zone"
  type        = string
  default     = "10.0.3.0/24"
}

variable "streamlit_image_uri" {
  description = "Image URI for the Streamlit container"
  type        = string
  default     = "<AccountID>.dkr.ecr.<Region>.amazonaws.com/<ImageName>:<Tag>"
}

variable "cpu" {
  description = "CPU of Fargate Task"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Memory of Fargate Task"
  type        = number
  default     = 1024
}

variable "desired_task_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Minimum containers for Autoscaling"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Maximum containers for Autoscaling"
  type        = number
  default     = 2
}

variable "autoscaling_target_value" {
  description = "CPU Utilization Target"
  type        = number
  default     = 80
}

variable "container_port" {
  description = "Port for the Docker container"
  type        = number
  default     = 80
}

variable "logging_bucket_name" {
  description = "Name of the S3 bucket for logging"
  type        = string
  default     = "streamlit-logging-bucket"
}