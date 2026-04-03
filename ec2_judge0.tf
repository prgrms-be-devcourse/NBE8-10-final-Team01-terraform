# ============================================================
# Judge0 채점 서버 EC2
# Ubuntu 22.04 사용 (cgroup v1 필요 - isolate 샌드박스 요구사항)
# ============================================================

resource "aws_instance" "judge0" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_4.id
  vpc_security_group_ids      = [aws_security_group.ec2_common.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  user_data = templatefile("${path.module}/user_data_judge0.sh", {
    count_of_workers  = var.count_of_workers
    postgres_password = var.judge0_db_password
    memory_limit      = var.memory_limit
    cpu_time_limit    = var.cpu_time_limit
  })

  tags = {
    Name    = "${var.project_name}-judge0"
    Project = var.project_name
  }
}

# 고정 공인 IP (application.yml의 judge0.url에 사용)
resource "aws_eip" "judge0" {
  instance = aws_instance.judge0.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-judge0-eip"
    Project = var.project_name
  }
}
