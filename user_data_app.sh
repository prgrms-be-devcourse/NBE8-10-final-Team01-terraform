#!/bin/bash
# 앱 서버 (Blue/Green) 부트스트랩 스크립트 (Amazon Linux 2023)
# CI/CD가 실제 앱 컨테이너를 배포함. 이 스크립트는 Docker 환경만 준비.
# 설치 로그: /var/log/user-data.log

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "========================================"
echo " 앱 서버 (${server_name}) 설정 시작"
echo " $(date)"
echo "========================================"

# 타임존 설정
timedatectl set-timezone Asia/Seoul

# Git, Docker 설치
dnf update -y
dnf install -y git docker

# Docker 서비스 등록 및 시작
systemctl enable docker
systemctl start docker

# Swap 4GB 생성
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sh -c 'echo "/swapfile swap swap defaults 0 0" >> /etc/fstab'
echo 'vm.swappiness = 10' >> /etc/sysctl.conf
sysctl -p

# 호스트명 설정
hostnamectl set-hostname ${server_name}

# 환경변수 설정 (/etc/environment)
# CI/CD 및 앱 컨테이너가 이 값들을 참조
echo 'SERVER_NAME=${server_name}' >> /etc/environment
echo 'RDS_HOST=${rds_endpoint}' >> /etc/environment
echo 'RDS_PORT=${rds_port}' >> /etc/environment
echo 'RDS_DB_NAME=${rds_db_name}' >> /etc/environment
echo 'RDS_USERNAME=${rds_username}' >> /etc/environment
echo 'REDIS_HOST=${elasticache_endpoint}' >> /etc/environment
echo 'REDIS_PORT=6379' >> /etc/environment
echo 'GITHUB_OWNER=${github_access_token_1_owner}' >> /etc/environment
source /etc/environment

# Docker 네트워크 생성
docker network create common

# GitHub Container Registry 로그인 (CI/CD에서 이미지 pull 시 사용)
echo '${github_access_token_1}' | docker login ghcr.io -u '${github_access_token_1_owner}' --password-stdin

echo "========================================"
echo " 앱 서버 (${server_name}) 설정 완료!"
echo " RDS 호스트: ${rds_endpoint}"
echo " Redis 호스트: ${elasticache_endpoint}"
echo " CI/CD를 통해 앱 컨테이너를 배포하세요."
echo "========================================"
