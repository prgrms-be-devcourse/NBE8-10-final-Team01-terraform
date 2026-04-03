# ─────────────────────────────────────
# 공통
# ─────────────────────────────────────
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 이름/태그에 prefix로 사용)"
  type        = string
  default     = "devcos-team01-ec2"
}

variable "key_pair_name" {
  description = "SSH 접속용 EC2 Key Pair 이름 (없어도 SSM Session Manager로 접속 가능)"
  type        = string
  default     = null
}

variable "password_1" {
  description = "공통 관리자 비밀번호 (NPM Plus 관리자, Grafana 관리자 등)"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────
# GitHub
# ─────────────────────────────────────
variable "github_access_token_1_owner" {
  description = "GitHub Container Registry 사용자명 (ghcr.io 로그인)"
  type        = string
}

variable "github_access_token_1" {
  description = "GitHub Personal Access Token (packages:read 권한 필요)"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────
# RDS PostgreSQL
# ─────────────────────────────────────
variable "rds_db_name" {
  description = "RDS 기본 DB 이름"
  type        = string
  default     = "appdb"
}

variable "rds_username" {
  description = "RDS 마스터 계정 이름"
  type        = string
  default     = "postgres"
}

variable "rds_password" {
  description = "RDS 마스터 계정 비밀번호"
  type        = string
  sensitive   = true
}

# ─────────────────────────────────────
# Judge0
# ─────────────────────────────────────
variable "count_of_workers" {
  description = "Judge0 워커 수 (동시 채점 가능 수)"
  type        = number
  default     = 2
}

variable "judge0_db_password" {
  description = "Judge0 내부 PostgreSQL 비밀번호"
  type        = string
  sensitive   = true
}

variable "memory_limit" {
  description = "Judge0 제출당 메모리 제한 (MB)"
  type        = number
  default     = 256
}

variable "cpu_time_limit" {
  description = "Judge0 제출당 CPU 시간 제한 (초)"
  type        = number
  default     = 5
}
