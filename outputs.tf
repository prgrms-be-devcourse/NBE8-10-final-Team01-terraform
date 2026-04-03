# ─────────────────────────────────────
# EC2 접속 정보
# ─────────────────────────────────────
output "public_ip" {
  description = "EC2 고정 공인 IP (DNS A레코드 연결)"
  value       = aws_eip.main.public_ip
}

output "ssh_command" {
  description = "SSH 접속 명령어"
  value       = var.key_pair_name != null ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.main.public_ip}" : "SSH 접속하려면 dev.tfvars의 key_pair_name 설정 필요"
}

# ─────────────────────────────────────
# 컨테이너 서비스 URL
# ─────────────────────────────────────
output "npm_admin_url" {
  description = "NPM Plus 관리자 패널 (초기 계정: admin@npm.com / password_1)"
  value       = "http://${aws_eip.main.public_ip}:81"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_eip.main.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL (admin / password_1 변수로 로그인)"
  value       = "http://${aws_eip.main.public_ip}:3000"
}

output "judge0_url" {
  description = "Judge0 API URL → application.yml judge0.url에 설정"
  value       = "http://${aws_eip.main.public_ip}:2358"
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
