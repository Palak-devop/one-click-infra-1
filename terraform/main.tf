terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # S3 backend configuration for Phase 10 DR
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "monitoring-stack/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-locks"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ==============================================================================
# NETWORKING (VPC, Subnets, Gateways, Route Tables)
# ==============================================================================

resource "aws_vpc" "monitoring_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "monitoring-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.monitoring_vpc.id

  tags = {
    Name = "monitoring-igw"
  }
}

# Public Subnets (AZ-1 & AZ-2)
resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.monitoring_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "monitoring-public-subnet-${count.index + 1}"
  }
}

# Private Subnets (AZ-1 & AZ-2)
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.monitoring_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "monitoring-private-subnet-${count.index + 1}"
  }
}

# NAT Gateway and EIP (Located in Public Subnet 1)
resource "aws_eip" "nat_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "monitoring-nat-eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "monitoring-nat-gw"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.monitoring_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "monitoring-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table (Routes via NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.monitoring_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name = "monitoring-private-rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Jenkins & Bastion Security Group (Public)
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-bastion-sg"
  description = "Allow SSH and Jenkins traffic to Public Instance"
  vpc_id      = aws_vpc.monitoring_vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "Jenkins web interface"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow reverse proxy to Grafana/Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-bastion-sg"
  }
}

# Private Subnet Security Group
resource "aws_security_group" "private_sg" {
  name        = "monitoring-private-sg"
  description = "Security group for private monitoring infrastructure nodes"
  vpc_id      = aws_vpc.monitoring_vpc.id

  ingress {
    description     = "Allow SSH from Jenkins/Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.jenkins_sg.id]
  }

  ingress {
    description = "Allow all VPC internal communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "monitoring-private-sg"
  }
}

# ==============================================================================
# COMPUTE RESOURCES (EC2 INSTANCES)
# ==============================================================================

# Query the latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2-1: Jenkins + Bastion Server (Public Subnet 1)
resource "aws_instance" "jenkins_bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.jenkins_instance_type
  subnet_id              = aws_subnet.public_subnets[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  user_data              = file("${path.module}/scripts/install-jenkins.sh")

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "EC2-1-Jenkins-Bastion"
  }
}

# EC2-2: VictoriaMetrics Ingestion/Query 1 (vminsert-1 + vmselect-1) - Private Subnet 1
resource "aws_instance" "vm_insert_select_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vm_instance_type
  subnet_id              = aws_subnet.private_subnets[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "EC2-2-vminsert-vmselect-1"
  }
}

# EC2-3: VictoriaMetrics Storage 1 (vmstorage-1) - Private Subnet 1
resource "aws_instance" "vm_storage_1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vm_instance_type
  subnet_id              = aws_subnet.private_subnets[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "EC2-3-vmstorage-1"
  }
}

# Dedicated EBS Volume for EC2-3 vmstorage-1
resource "aws_ebs_volume" "storage_vol_1" {
  availability_zone = var.availability_zones[0]
  size              = 20
  type              = "gp3"

  tags = {
    Name = "vmstorage-ebs-1"
  }
}

resource "aws_volume_attachment" "storage_attach_1" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.storage_vol_1.id
  instance_id = aws_instance.vm_storage_1.id
}

# EC2-4: VictoriaMetrics Ingestion/Query 2 (vminsert-2 + vmselect-2) - Private Subnet 2
resource "aws_instance" "vm_insert_select_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vm_instance_type
  subnet_id              = aws_subnet.private_subnets[1].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "EC2-4-vminsert-vmselect-2"
  }
}

# EC2-5: VictoriaMetrics Storage 2 (vmstorage-2) - Private Subnet 2
resource "aws_instance" "vm_storage_2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.vm_instance_type
  subnet_id              = aws_subnet.private_subnets[1].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "EC2-5-vmstorage-2"
  }
}

# Dedicated EBS Volume for EC2-5 vmstorage-2
resource "aws_ebs_volume" "storage_vol_2" {
  availability_zone = var.availability_zones[1]
  size              = 20
  type              = "gp3"

  tags = {
    Name = "vmstorage-ebs-2"
  }
}

resource "aws_volume_attachment" "storage_attach_2" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.storage_vol_2.id
  instance_id = aws_instance.vm_storage_2.id
}

# EC2-6: Monitoring (Nginx + Exporters + vmagent) - Private Subnet 1
resource "aws_instance" "monitoring" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.monitoring_instance_type
  subnet_id              = aws_subnet.private_subnets[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "EC2-6-Monitoring-Target"
  }
}

# EC2-7: Grafana Server - Private Subnet 2
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.grafana_instance_type
  subnet_id              = aws_subnet.private_subnets[1].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  tags = {
    Name = "EC2-7-Grafana"
  }
}

