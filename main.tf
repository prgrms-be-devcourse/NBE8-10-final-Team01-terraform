# ============================================================
# Judge0 EC2 Terraform 설정
#
# 사용법:
#   export AWS_PROFILE=team (bash, 현재 터미널에서 기본 프로필을 team으로 잡기) (powershell: $env:AWS_PROFILE="team")
#   terraform init
#   terraform apply -var-file="dev.tfvars"
#   (약 8~10분 후 Judge0 준비 완료)
#
#   terraform destroy -var-file=dev.tfvars
#
# apply 완료 후 출력되는 judge0_url을 application-dev.yml에 설정
# ============================================================

terraform {
  required_version = ">= 1.5"

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

# Ubuntu 22.04 LTS 최신 AMI 자동 조회
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

# Security Group
resource "aws_security_group" "judge0" {
  name        = "${var.project_name}-judge0-sg"
  description = "Judge0 server access"

  # Judge0 API
  ingress {
    description = "Judge0 API"
    from_port   = 2358
    to_port     = 2358
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # SSH (디버깅용)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Docker pull, apt-get 등 외부 통신
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-judge0-sg"
    Project = var.project_name
  }
}

# EC2 인스턴스
resource "aws_instance" "judge0" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.judge0.id]

  user_data = templatefile("${path.module}/user_data.sh", {
    count_of_workers  = var.count_of_workers
    postgres_password = var.postgres_password
    memory_limit      = var.memory_limit
    cpu_time_limit    = var.cpu_time_limit
  })

  root_block_device {
    volume_size           = 20  # Judge0 이미지 + 실행 데이터
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name    = "${var.project_name}-judge0"
    Project = var.project_name
  }
}

# Elastic IP: destroy/apply 해도 IP 고정
resource "aws_eip" "judge0" {
  instance = aws_instance.judge0.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-judge0-eip"
    Project = var.project_name
  }
}
