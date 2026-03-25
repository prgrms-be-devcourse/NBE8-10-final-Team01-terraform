output "judge0_url" {
  description = "Judge0 API URL → application-dev.yml의 judge0.url에 설정"
  value       = "http://${aws_eip.judge0.public_ip}:2358"
}

output "public_ip" {
  description = "EC2 공인 IP"
  value       = aws_eip.judge0.public_ip
}

output "ssh_command" {
  description = "SSH 접속 명령어 (key_pair_name 설정 시 사용 가능)"
  value       = var.key_pair_name != null ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.judge0.public_ip}" : "SSH 접속하려면 variables.tf의 key_pair_name 설정 필요"
}

output "setup_log_command" {
  description = "EC2 설정 로그 확인 명령어"
  value       = var.key_pair_name != null ? "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${aws_eip.judge0.public_ip} 'sudo tail -f /var/log/user-data.log'" : "SSH key 필요"
}
