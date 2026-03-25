variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 태그에 사용)"
  type        = string
  default     = "nbe8-10-team01"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입 (t3.small 최소 / t3.medium 권장)"
  type        = string
  default     = "t3.small"
}

variable "key_pair_name" {
  description = "SSH 접속용 EC2 Key Pair 이름 (디버깅용, 없어도 동작함)"
  type        = string
  default     = null
}

variable "allowed_cidr_blocks" {
  description = "Judge0 API 및 SSH 접근 허용 CIDR (개발용은 전체 오픈)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "count_of_workers" {
  description = "Judge0 워커 수 (동시 채점 가능 수)"
  type        = number
  default     = 2
}

variable "postgres_password" {
  description = "Judge0 DB 비밀번호"
  type        = string
  sensitive   = true
}

variable "memory_limit" {
  description = "제출당 메모리 제한 (MB)"
  type        = number
  default     = 256
}

variable "cpu_time_limit" {
  description = "제출당 CPU 시간 제한 (초)"
  type        = number
  default     = 5
}
