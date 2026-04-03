#!/bin/bash
# Nginx Proxy Manager Plus 부트스트랩 스크립트 (Amazon Linux 2023)
# 설치 로그: /var/log/user-data.log

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "========================================"
echo " Nginx NPM Plus EC2 설정 시작"
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

# Swap 4GB 생성 (메모리 부족 방지)
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sh -c 'echo "/swapfile swap swap defaults 0 0" >> /etc/fstab'
echo 'vm.swappiness = 10' >> /etc/sysctl.conf
sysctl -p

# 호스트명 설정
hostnamectl set-hostname nginx

# Docker 네트워크 생성
docker network create common

# NPM Plus 컨테이너 실행
# 포트: 80(HTTP), 443(HTTPS), 81(관리자 패널)
docker run -d \
  --name npm_1 \
  --restart unless-stopped \
  --network common \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -p 81:81 \
  -e TZ=Asia/Seoul \
  -e INITIAL_ADMIN_EMAIL=admin@npm.com \
  -e 'INITIAL_ADMIN_PASSWORD=${password_1}' \
  -v /dockerProjects/npm_1/volumes/data:/data \
  zoeyvid/npmplus:latest

echo "========================================"
echo " Nginx NPM Plus 설정 완료!"
echo " 관리자 패널: http://<공인IP>:81"
echo " 초기 계정: admin@npm.com / ${password_1}"
echo "========================================"
