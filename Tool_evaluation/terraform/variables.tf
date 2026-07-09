variable "aws_region" {
  description = "AWS Region to deploy the infrastructure"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "availability_zones" {
  description = "Availability zones in the region"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "key_name" {
  description = "Name of the SSH Key Pair to access instances"
  type        = string
  default     = "monitoring-key"
}

variable "allowed_ssh_cidr" {
  description = "Allowed CIDR block to access Bastion Host and Jenkins"
  type        = string
  default     = "0.0.0.0/0" # In production, restrict this to operator's public IP
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins/Bastion host"
  type        = string
  default     = "t3.medium" # Needs more memory for Jenkins and builds
}

variable "vm_instance_type" {
  description = "Instance type for VictoriaMetrics cluster nodes"
  type        = string
  default     = "t3.small"
}

variable "monitoring_instance_type" {
  description = "Instance type for Nginx and exporter nodes"
  type        = string
  default     = "t3.micro"
}

variable "grafana_instance_type" {
  description = "Instance type for Grafana server"
  type        = string
  default     = "t3.micro"
}
