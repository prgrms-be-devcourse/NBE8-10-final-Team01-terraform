# ============================================================
# 애플리케이션 서버 - Blue/Green 배포
# Blue: 현재 운영 중인 서버
# Green: 다음 배포 대상 서버
# ============================================================

# Blue 서버
resource "aws_instance" "app_blue" {
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

  user_data = templatefile("${path.module}/user_data_app.sh", {
    server_name                 = "app-blue"
    rds_endpoint                = aws_db_instance.main.address
    rds_port                    = aws_db_instance.main.port
    rds_db_name                 = var.rds_db_name
    rds_username                = var.rds_username
    elasticache_endpoint        = aws_elasticache_cluster.redis.cache_nodes[0].address
    github_access_token_1_owner = var.github_access_token_1_owner
    github_access_token_1       = var.github_access_token_1
  })

  tags = {
    Name    = "${var.project_name}-app-blue"
    Project = var.project_name
    Role    = "blue"
  }
}

# Green 서버
resource "aws_instance" "app_green" {
  ami                         = data.aws_ssm_parameter.amazon_linux_ami.value
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_2.id
  vpc_security_group_ids      = [aws_security_group.ec2_common.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
  }

  user_data = templatefile("${path.module}/user_data_app.sh", {
    server_name                 = "app-green"
    rds_endpoint                = aws_db_instance.main.address
    rds_port                    = aws_db_instance.main.port
    rds_db_name                 = var.rds_db_name
    rds_username                = var.rds_username
    elasticache_endpoint        = aws_elasticache_cluster.redis.cache_nodes[0].address
    github_access_token_1_owner = var.github_access_token_1_owner
    github_access_token_1       = var.github_access_token_1
  })

  tags = {
    Name    = "${var.project_name}-app-green"
    Project = var.project_name
    Role    = "green"
  }
}
