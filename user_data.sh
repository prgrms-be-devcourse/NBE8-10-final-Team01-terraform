#!/bin/bash
# Judge0 EC2 자동 설치 스크립트 (Terraform templatefile)
# 설치 로그: /var/log/user-data.log

set -ex
exec > >(tee /var/log/user-data.log) 2>&1

echo "========================================"
echo " Judge0 EC2 설정 시작"
echo " $(date)"
echo "========================================"

# ─────────────────────────────────────────
# 1. Docker 설치 (공식 스크립트 사용)
# ─────────────────────────────────────────
echo "[1/5] Docker 설치 중..."

apt-get update -y
apt-get install -y curl

curl -fsSL https://get.docker.com | sh

systemctl enable docker
systemctl start docker

# ubuntu 유저가 sudo 없이 docker 사용 가능하도록
usermod -aG docker ubuntu

echo "[1/5] Docker 설치 완료"

# ─────────────────────────────────────────
# 2. cgroup v1 활성화 (Judge0 isolate 필수 요구사항)
#    Ubuntu 22.04는 기본 cgroup v2 → v1으로 전환
#    재부팅 후 적용됨
# ─────────────────────────────────────────
echo "[2/5] cgroup v1 설정 중..."

# AWS EC2는 /etc/default/grub.d/50-cloudimg-settings.cfg가
# /etc/default/grub 설정을 덮어쓰므로 더 높은 우선순위 파일로 설정
cat > /etc/default/grub.d/99-judge0-cgroup.cfg << 'GRUBEOF'
GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT systemd.unified_cgroup_hierarchy=0 cgroup_enable=memory swapaccount=1"
GRUBEOF

update-grub

# Docker가 cgroup v1을 직접 사용하도록 설정
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'DOCKEREOF'
{
  "exec-opts": ["native.cgroupdriver=cgroupfs"]
}
DOCKEREOF

echo "[2/5] cgroup v1 설정 완료 (재부팅 후 적용)"

# ─────────────────────────────────────────
# 3. Judge0 docker-compose 파일 생성
#    Terraform 변수: ${count_of_workers}, ${postgres_password}
#                   ${memory_limit}, ${cpu_time_limit}
# ─────────────────────────────────────────
echo "[3/5] Judge0 docker-compose 설정 중..."

mkdir -p /opt/judge0

cat > /opt/judge0/docker-compose.yml << 'COMPOSEEOF'
services:
  # Judge0 API 서버
  judge0-server:
    image: judge0/judge0:1.13.1
    environment:
      REDIS_HOST: judge0-redis
      REDIS_PORT: 6379
      POSTGRES_HOST: judge0-db
      POSTGRES_PORT: 5432
      POSTGRES_DB: judge0
      POSTGRES_USER: judge0
      POSTGRES_PASSWORD: ${postgres_password}
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

  # Judge0 워커 (실제 코드 실행 담당)
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
      POSTGRES_PASSWORD: ${postgres_password}
      COUNT_OF_WORKERS: "${count_of_workers}"
      INTERVAL: "1"
      MEMORY_LIMIT: "${memory_limit}"
      CPU_TIME_LIMIT: "${cpu_time_limit}"
      WALL_TIME_LIMIT: "10"
    privileged: true
    restart: always
    depends_on:
      judge0-db:
        condition: service_healthy
      judge0-redis:
        condition: service_healthy

  # Judge0 전용 PostgreSQL
  judge0-db:
    image: postgres:13
    environment:
      POSTGRES_DB: judge0
      POSTGRES_USER: judge0
      POSTGRES_PASSWORD: ${postgres_password}
    volumes:
      - judge0_db_data:/var/lib/postgresql/data
    restart: always
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U judge0 -d judge0"]
      interval: 5s
      timeout: 5s
      retries: 20

  # Judge0 전용 Redis (작업 큐)
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

echo "[3/5] docker-compose 설정 완료"

# ─────────────────────────────────────────
# 4. Docker 이미지 사전 다운로드 (재부팅 후 빠른 시작을 위해)
# ─────────────────────────────────────────
echo "[4/5] Docker 이미지 사전 다운로드 중..."

docker pull judge0/judge0:1.13.1
docker pull postgres:13
docker pull redis:6

echo "[4/5] Docker 이미지 다운로드 완료"

# ─────────────────────────────────────────
# 5. 재부팅 후 Judge0 자동 시작 systemd 서비스 등록
# ─────────────────────────────────────────
echo "[5/5] Judge0 systemd 서비스 등록 중..."

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

echo "[5/5] systemd 서비스 등록 완료"

echo "========================================"
echo " 설정 완료! cgroup v1 적용을 위해 재부팅합니다."
echo " 재부팅 후 Judge0가 자동으로 시작됩니다. (약 2~3분 소요)"
echo " 준비 확인: curl http://localhost:2358/system_info"
echo "========================================"

reboot
