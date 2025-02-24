variable "ami_id" {
  description = "AMI ID for EC2 instances"
  default        = "ami-0076be86944570bff"
}

variable "key_name" {
  description = "SSH Key name for EC2 instances"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the Auto Scaling Group"
  type        = list(string)
  default = [ "subnet-07556958c4b78c1d1", "subnet-0eba4d18753c4a24f" ]
}

variable "node_count" {
  description = "Number of RabbitMQ nodes to create"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC ID where resources will be created"
  default = "vpc-0268ac8e1bba7c30c"
}