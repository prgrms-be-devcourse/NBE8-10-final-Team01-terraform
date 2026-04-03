# ============================================================
# Nginx Proxy Manager Plus (NPM+) EC2
# 역할: 외부 트래픽 진입점, SSL 종료, Blue/Green 라우팅
# ============================================================

resource "aws_instance" "nginx" {
  ami                         = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_common.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = templatefile("${path.module}/user_data_nginx.sh", {
    password_1 = var.password_1
  })

  tags = {
    Name    = "${var.project_name}-nginx"
    Project = var.project_name
  }
}

# 고정 공인 IP (도메인 A레코드 연결용)
resource "aws_eip" "nginx" {
  instance = aws_instance.nginx.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-nginx-eip"
    Project = var.project_name
  }
}
