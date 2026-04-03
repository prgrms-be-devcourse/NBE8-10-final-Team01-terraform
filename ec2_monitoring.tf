# ============================================================
# 모니터링 EC2 - Prometheus + Grafana
# Prometheus: Blue/Green 앱 메트릭 수집 (포트 9090)
# Grafana:    대시보드 시각화 (포트 3000)
# ============================================================

resource "aws_instance" "monitoring" {
  ami                         = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_3.id
  vpc_security_group_ids      = [aws_security_group.ec2_common.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  # app_blue, app_green의 private IP를 Prometheus 스크래이프 대상으로 주입
  user_data = templatefile("${path.module}/user_data_monitoring.sh", {
    password_1   = var.password_1
    app_blue_ip  = aws_instance.app_blue.private_ip
    app_green_ip = aws_instance.app_green.private_ip
    app_port     = var.app_port
  })

  tags = {
    Name    = "${var.project_name}-monitoring"
    Project = var.project_name
  }
}
