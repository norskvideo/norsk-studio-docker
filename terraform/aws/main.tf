terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources for AMI lookup
data "aws_ami" "ubuntu_24_04" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id         = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu_24_04[0].id
  create_vpc     = var.vpc_id == ""
  create_subnet  = var.subnet_id == ""
  vpc_id         = local.create_vpc ? aws_vpc.main[0].id : var.vpc_id
  subnet_id      = local.create_subnet ? aws_subnet.main[0].id : var.subnet_id
}

# VPC (if not provided)
resource "aws_vpc" "main" {
  count                = local.create_vpc ? 1 : 0
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

resource "aws_internet_gateway" "main" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

resource "aws_subnet" "main" {
  count                   = local.create_subnet ? 1 : 0
  vpc_id                  = local.vpc_id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name    = "${var.project_name}-subnet"
    Project = var.project_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_route_table" "main" {
  count  = local.create_vpc ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name    = "${var.project_name}-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "main" {
  count          = local.create_subnet ? 1 : 0
  subnet_id      = aws_subnet.main[0].id
  route_table_id = aws_route_table.main[0].id
}

# Security Group
resource "aws_security_group" "norsk_studio" {
  name        = "${var.project_name}-sg"
  description = "Security group for Norsk Studio"
  vpc_id      = local.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_http_cidrs
  }

  ingress {
    description = "UDP ingress"
    from_port   = 5001
    to_port     = 5001
    protocol    = "udp"
    cidr_blocks = var.allowed_http_cidrs
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# SSM Parameters for secrets
resource "aws_ssm_parameter" "norsk_license" {
  name        = "/norsk/license"
  description = "Norsk license JSON"
  type        = "SecureString"
  value       = var.norsk_license_json

  tags = {
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "studio_password" {
  name        = "/norsk/password"
  description = "Norsk Studio admin password"
  type        = "SecureString"
  value       = var.studio_password

  tags = {
    Project = var.project_name
  }
}

# IAM Role for EC2 instance
resource "aws_iam_role" "norsk_studio" {
  name = "${var.project_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project = var.project_name
  }
}

resource "aws_iam_role_policy" "norsk_studio" {
  name = "${var.project_name}-policy"
  role = aws_iam_role.norsk_studio.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.norsk_license.arn,
          aws_ssm_parameter.studio_password.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeTags"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "norsk_studio" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.norsk_studio.name

  tags = {
    Project = var.project_name
  }
}

# EC2 Instance
resource "aws_instance" "norsk_studio" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.norsk_studio.id]
  iam_instance_profile        = aws_iam_instance_profile.norsk_studio.name
  associate_public_ip_address = true

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.enable_imdsv2 ? "required" : "optional"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  user_data = templatefile("${path.module}/userdata.sh", {
    repo_branch       = var.repo_branch
    hardware_override = var.hardware_profile
  })

  tags = {
    Name            = "${var.project_name}-instance"
    Project         = var.project_name
    DomainName      = var.domain_name
    CertbotEmail    = var.certbot_email
    HardwareProfile = var.hardware_profile
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP (optional, for stable public IP)
resource "aws_eip" "norsk_studio" {
  instance = aws_instance.norsk_studio.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}
