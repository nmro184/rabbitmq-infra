variable "aws_region" {
  description = "AWS Region where resources will be deployed"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for EC2 instances"
  default     = "ami-0076be86944570bff"
}

variable "ssh_key_name" {
  description = "SSH Key name for EC2 instances"
  type        = string
}

variable "ssh_key_path" {
  description = "SSH Key path for EC2 instances"
  type        = string
}


variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)
}

variable "node_count" {
  description = "Number of RabbitMQ nodes to create"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  type        = string
}
