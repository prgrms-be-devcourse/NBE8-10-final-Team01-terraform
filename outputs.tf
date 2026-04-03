# ─────────────────────────────────────
# Nginx (외부 진입점)
# ─────────────────────────────────────
output "nginx_public_ip" {
  description = "Nginx NPM Plus 고정 공인 IP → DNS A레코드 연결"
  value       = aws_eip.nginx.public_ip
}

output "npm_admin_url" {
  description = "NPM Plus 관리자 패널 URL (초기 계정: admin@npm.com / password_1)"
  value       = "http://${aws_eip.nginx.public_ip}:81"
}

# ─────────────────────────────────────
# App 서버 (Blue/Green)
# ─────────────────────────────────────
output "app_blue_private_ip" {
  description = "Blue 서버 내부 IP (NPM Plus 업스트림 설정용)"
  value       = aws_instance.app_blue.private_ip
}

output "app_blue_public_ip" {
  description = "Blue 서버 공인 IP (SSH 접속용)"
  value       = aws_instance.app_blue.public_ip
}

output "app_green_private_ip" {
  description = "Green 서버 내부 IP (NPM Plus 업스트림 설정용)"
  value       = aws_instance.app_green.private_ip
}

output "app_green_public_ip" {
  description = "Green 서버 공인 IP (SSH 접속용)"
  value       = aws_instance.app_green.public_ip
}

# ─────────────────────────────────────
# RDS
# ─────────────────────────────────────
output "rds_endpoint" {
  description = "RDS 엔드포인트 → application.yml spring.datasource.url에 설정"
  value       = aws_db_instance.main.address
}

output "rds_jdbc_url" {
  description = "Spring Boot JDBC URL 예시"
  value       = "jdbc:postgresql://${aws_db_instance.main.address}:5432/${var.rds_db_name}"
}

# ─────────────────────────────────────
# ElastiCache Redis
# ─────────────────────────────────────
output "redis_endpoint" {
  description = "Redis 엔드포인트 → application.yml spring.data.redis.host에 설정"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis 포트"
  value       = aws_elasticache_cluster.redis.port
}

# ─────────────────────────────────────
# 모니터링
# ─────────────────────────────────────
output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.monitoring.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL (admin / password_1 변수로 로그인)"
  value       = "http://${aws_instance.monitoring.public_ip}:3000"
}

# ─────────────────────────────────────
# Judge0
# ─────────────────────────────────────
output "judge0_url" {
  description = "Judge0 API URL → application.yml judge0.url에 설정"
  value       = "http://${aws_eip.judge0.public_ip}:2358"
}

output "judge0_public_ip" {
  description = "Judge0 EC2 고정 공인 IP"
  value       = aws_eip.judge0.public_ip
}
