#!/bin/bash
# 모니터링 서버 (Prometheus + Grafana) 부트스트랩 스크립트 (Amazon Linux 2023)
# 설치 로그: /var/log/user-data.log

set -euxo pipefail
exec > >(tee /var/log/user-data.log) 2>&1

echo "========================================"
echo " 모니터링 EC2 설정 시작"
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
hostnamectl set-hostname monitoring

# Docker 네트워크 생성
docker network create common

# ─────────────────────────────────────
# Prometheus 설정 파일 생성
# app_blue_ip, app_green_ip는 Terraform이 EC2 private IP로 치환
# ─────────────────────────────────────
mkdir -p /dockerProjects/prometheus/config

cat > /dockerProjects/prometheus/config/prometheus.yml << 'PROMEOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'app-blue'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['${app_blue_ip}:${app_port}']

  - job_name: 'app-green'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['${app_green_ip}:${app_port}']
PROMEOF

# ─────────────────────────────────────
# Grafana 프로비저닝 (Prometheus 데이터소스 자동 등록)
# ─────────────────────────────────────
mkdir -p /dockerProjects/grafana/provisioning/datasources
mkdir -p /dockerProjects/grafana/volumes/data

cat > /dockerProjects/grafana/provisioning/datasources/prometheus.yml << 'GRAFEOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus_1:9090
    isDefault: true
    access: proxy
GRAFEOF

# ─────────────────────────────────────
# Prometheus 컨테이너 실행 (포트 9090)
# ─────────────────────────────────────
docker run -d \
  --name prometheus_1 \
  --restart unless-stopped \
  --network common \
  -p 9090:9090 \
  -e TZ=Asia/Seoul \
  -v /dockerProjects/prometheus/config:/etc/prometheus \
  prom/prometheus:latest

# ─────────────────────────────────────
# Grafana 컨테이너 실행 (포트 3000)
# ─────────────────────────────────────
docker run -d \
  --name grafana_1 \
  --restart unless-stopped \
  --network common \
  -p 3000:3000 \
  -e TZ=Asia/Seoul \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e 'GF_SECURITY_ADMIN_PASSWORD=${password_1}' \
  -v /dockerProjects/grafana/volumes/data:/var/lib/grafana \
  -v /dockerProjects/grafana/provisioning:/etc/grafana/provisioning \
  grafana/grafana:latest

echo "========================================"
echo " 모니터링 설정 완료!"
echo " Prometheus: http://<공인IP>:9090"
echo " Grafana:    http://<공인IP>:3000"
echo " Grafana 계정: admin / ${password_1}"
echo " 스크래이프 대상: ${app_blue_ip}:${app_port}, ${app_green_ip}:${app_port}"
echo "========================================"
