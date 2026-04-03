# ============================================================
# 메인 EC2 (단일 서버) - Ubuntu 22.04
# 실행 컨테이너: NPM Plus, Prometheus, Grafana, Judge0
# CI/CD가 추가로 배포: App Blue, App Green
# ============================================================

locals {
  ec2_bootstrap = <<-EOF
#!/bin/bash
set -euxo pipefail

LOG_FILE="/var/log/bootstrap.log"
exec > >(tee -a $LOG_FILE) 2>&1

echo "BOOTSTRAP START"

# ─────────────────────────────────────
# 타임존 설정
# ─────────────────────────────────────
timedatectl set-timezone Asia/Seoul

# ─────────────────────────────────────
# Docker 설치 (Ubuntu 공식 스크립트)
# ─────────────────────────────────────
apt-get update -y
apt-get install -y curl git

curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# ─────────────────────────────────────
# cgroup v1 설정 (Judge0 isolate 필수)
# Ubuntu 22.04 기본은 cgroup v2 → v1으로 전환
# 재부팅 후 적용됨
# ─────────────────────────────────────
cat > /etc/default/grub.d/99-judge0-cgroup.cfg << 'GRUBEOF'
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT systemd.unified_cgroup_hierarchy=0 cgroup_enable=memory swapaccount=1"
GRUBEOF

update-grub

mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKEREOF'
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
DOCKEREOF

# ─────────────────────────────────────
# Swap 4GB 생성
# 단일 EC2에 컨테이너 다수 운영 → 여유 확보
# ─────────────────────────────────────
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
sh -c 'echo "/swapfile swap swap defaults 0 0" >> /etc/fstab'
echo 'vm.swappiness = 10' >> /etc/sysctl.conf
sysctl -p

# ─────────────────────────────────────
# 환경변수 설정 (/etc/environment)
# CI/CD 및 앱 컨테이너에서 참조
# ─────────────────────────────────────
echo 'PASSWORD_1=${var.password_1}' >> /etc/environment
echo 'RDS_HOST=${aws_db_instance.main.address}' >> /etc/environment
echo 'REDIS_HOST=${aws_elasticache_cluster.redis.cache_nodes[0].address}' >> /etc/environment
echo 'GITHUB_ACCESS_TOKEN_1_OWNER=${var.github_access_token_1_owner}' >> /etc/environment
echo 'GITHUB_ACCESS_TOKEN_1=${var.github_access_token_1}' >> /etc/environment
source /etc/environment

# ─────────────────────────────────────
# Docker 네트워크 생성
# ─────────────────────────────────────
docker network create common

# ─────────────────────────────────────
# NPM Plus 설치
# 포트: 80(HTTP), 443(HTTPS), 81(관리자 패널)
# ─────────────────────────────────────
docker run -d \
  --name npm_1 \
  --restart unless-stopped \
  --network common \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -p 81:81 \
  -e TZ=Asia/Seoul \
  -e 'INITIAL_ADMIN_EMAIL=admin@npm.com' \
  -e 'INITIAL_ADMIN_PASSWORD=${var.password_1}' \
  -v /dockerProjects/npm_1/volumes/data:/data \
  zoeyvid/npmplus:latest

# ─────────────────────────────────────
# GitHub Container Registry 로그인
# CI/CD에서 앱 이미지 pull 시 사용
# ─────────────────────────────────────
echo '${var.github_access_token_1}' | docker login ghcr.io -u '${var.github_access_token_1_owner}' --password-stdin

# ─────────────────────────────────────
# Prometheus 설정 파일 생성
# 앱 컨테이너와 같은 common 네트워크 → container name으로 scrape
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
      - targets: ['app_blue:8080']

  - job_name: 'app-green'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['app_green:8080']
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
# Prometheus 컨테이너 실행
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
# Grafana 컨테이너 실행
# ─────────────────────────────────────
docker run -d \
  --name grafana_1 \
  --restart unless-stopped \
  --network common \
  -p 3000:3000 \
  -e TZ=Asia/Seoul \
  -e GF_SECURITY_ADMIN_USER=admin \
  -e 'GF_SECURITY_ADMIN_PASSWORD=${var.password_1}' \
  -v /dockerProjects/grafana/volumes/data:/var/lib/grafana \
  -v /dockerProjects/grafana/provisioning:/etc/grafana/provisioning \
  grafana/grafana:latest

# ─────────────────────────────────────
# Judge0 docker-compose 파일 생성
# ─────────────────────────────────────
mkdir -p /opt/judge0

cat > /opt/judge0/docker-compose.yml << 'COMPOSEEOF'
services:
  judge0-server:
    image: judge0/judge0:1.13.1
    environment:
      REDIS_HOST: judge0-redis
      REDIS_PORT: 6379
      POSTGRES_HOST: judge0-db
      POSTGRES_PORT: 5432
      POSTGRES_DB: judge0
      POSTGRES_USER: judge0
      POSTGRES_PASSWORD: ${var.judge0_db_password}
      JUDGE0_TELEMETRY_ENABLE: "false"
    ports:
      - "2358:2358"
    privileged: true
    restart: always
    depends_on:
      judge0-db:
        condition: service_healthy
      judge0-redis:
        condition: service_healthy

  judge0-workers:
    image: judge0/judge0:1.13.1
    command: ["./scripts/workers"]
    environment:
      REDIS_HOST: judge0-redis
      REDIS_PORT: 6379
      POSTGRES_HOST: judge0-db
      POSTGRES_PORT: 5432
      POSTGRES_DB: judge0
      POSTGRES_USER: judge0
      POSTGRES_PASSWORD: ${var.judge0_db_password}
      COUNT_OF_WORKERS: "${var.count_of_workers}"
      INTERVAL: "1"
      MEMORY_LIMIT: "${var.memory_limit}"
      CPU_TIME_LIMIT: "${var.cpu_time_limit}"
      WALL_TIME_LIMIT: "10"
    privileged: true
    restart: always
    depends_on:
      judge0-db:
        condition: service_healthy
      judge0-redis:
        condition: service_healthy

  judge0-db:
    image: postgres:13
    environment:
      POSTGRES_DB: judge0
      POSTGRES_USER: judge0
      POSTGRES_PASSWORD: ${var.judge0_db_password}
    volumes:
      - judge0_db_data:/var/lib/postgresql/data
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U judge0 -d judge0"]
      interval: 5s
      timeout: 5s
      retries: 20

  judge0-redis:
    image: redis:6
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 10

volumes:
  judge0_db_data:
COMPOSEEOF

# ─────────────────────────────────────
# Judge0 Docker 이미지 사전 다운로드
# 재부팅 후 빠른 시작을 위해 미리 pull
# ─────────────────────────────────────
docker pull judge0/judge0:1.13.1
docker pull postgres:13
docker pull redis:6

# ─────────────────────────────────────
# Judge0 systemd 서비스 등록
# 재부팅 후 docker compose up -d 자동 실행
# ─────────────────────────────────────
cat > /etc/systemd/system/judge0.service << 'SVCEOF'
[Unit]
Description=Judge0 Judging Service
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/judge0
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable judge0.service

echo "BOOTSTRAP DONE"
EOF
}

resource "aws_instance" "main" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.subnet_1.id
  vpc_security_group_ids      = [aws_security_group.ec2_common.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  key_name                    = var.key_pair_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  user_data = <<-EOF
    ${local.ec2_bootstrap}
    hostnamectl set-hostname ${var.project_name}
    reboot
  EOF

  tags = {
    Name    = "${var.project_name}-main"
    Project = var.project_name
    Team    = "devcos-team1"
  }
}

# 고정 공인 IP (도메인 연결, Judge0 URL 등에 사용)
resource "aws_eip" "main" {
  instance = aws_instance.main.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
    Team    = "devcos-team1"
  }
}
