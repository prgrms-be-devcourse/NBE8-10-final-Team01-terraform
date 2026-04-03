# ============================================================
# AWS RDS PostgreSQL
# ============================================================

# DB 서브넷 그룹 (Multi-AZ 지원을 위해 2개 AZ 필요)
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]

  tags = {
    Name    = "${var.project_name}-db-subnet-group"
    Project = var.project_name
    Team    = "devcos-team1"
  }
}

# RDS PostgreSQL 인스턴스
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-rds"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t3.small"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"

  db_name  = var.rds_db_name
  username = var.rds_username
  password = var.rds_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # 개발 환경: 단일 AZ, 외부 접근 불가 (VPC 내부에서만 접근)
  multi_az            = false
  publicly_accessible = false

  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Name    = "${var.project_name}-rds"
    Project = var.project_name
    Team    = "devcos-team1"
  }
}
