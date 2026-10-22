#!/usr/bin/env bash
# ============================================================
# Paperclip run script for Linux / WSL
# Usage: ./scripts/run.sh [--setup | --refresh | --help]
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

ENV_FILE="$PROJECT_ROOT/.env"
ENV_EXAMPLE="$PROJECT_ROOT/.env.example"
CONTAINER="paperclip-server"

usage() {
    cat << 'EOF'
Paperclip - AI Agent Control Plane

Usage: ./scripts/run.sh [option]

Options:
  (không có)    Chạy Paperclip (docker compose up -d) và chờ healthy
  --setup       Cài đặt lần đầu: tạo .env + secrets, tạo data dir, rồi chạy
                (an toàn khi chạy lại: .env đã có thì giữ nguyên)
  --refresh     Kéo image mới nhất và tạo lại container (dữ liệu giữ nguyên)
  -h, --help    Hiện hướng dẫn này

Ví dụ:
  ./scripts/run.sh --setup      # máy mới / vừa clone repo
  ./scripts/run.sh              # bật Paperclip
  ./scripts/run.sh --refresh    # cập nhật Paperclip

Lệnh khác:
  docker compose logs -f        # xem logs
  docker compose down           # dừng
  ./scripts/backup.sh           # backup data
  ./scripts/restore.sh          # khôi phục từ backup
EOF
}

check_docker() {
    echo -e "\033[1;33mChecking Docker...\033[0m"
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "  \033[1;31mERROR: Docker is not installed or not in PATH.\033[0m"
        echo -e "  Please install Docker or enable WSL integration in Docker Desktop."
        exit 1
    fi
    if ! docker compose version >/dev/null 2>&1; then
        echo -e "  \033[1;31mERROR: Docker Compose plugin is not available.\033[0m"
        exit 1
    fi
    if ! DOCKER_ERR=$(docker info 2>&1 >/dev/null); then
        if echo "$DOCKER_ERR" | grep -qi "permission denied"; then
            echo -e "  \033[1;31mERROR: User $(whoami) không có quyền dùng Docker.\033[0m"
            echo -e "  Chạy: sudo usermod -aG docker $(whoami)  rồi đăng xuất / đăng nhập lại."
        else
            echo -e "  \033[1;31mERROR: Docker daemon is not running.\033[0m"
            echo -e "  Linux: sudo systemctl start docker  |  WSL/Windows: mở Docker Desktop."
        fi
        exit 1
    fi
    echo -e "  \033[1;32mOK: $(docker --version)\033[0m"
    echo -e "  \033[1;32mOK: $(docker compose version)\033[0m"
    echo ""
}

create_env() {
    echo -e "\033[1;33mCreating .env file...\033[0m"
    if [ -f "$ENV_FILE" ]; then
        echo -e "  \033[1;33m.env already exists. Skipping recreation.\033[0m"
        echo ""
        return
    fi

    # Generate 32-byte hex secrets
    if command -v openssl >/dev/null 2>&1; then
        SECRET1=$(openssl rand -hex 32)
        SECRET2=$(openssl rand -hex 32)
    elif command -v python3 >/dev/null 2>&1; then
        SECRET1=$(python3 -c "import secrets; print(secrets.token_hex(32))")
        SECRET2=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    else
        SECRET1=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
        SECRET2=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    fi

    cp "$ENV_EXAMPLE" "$ENV_FILE"

    sed -i "s|BETTER_AUTH_SECRET=\"THAY_BANG_RANDOM_HEX_32_BYTES\"|BETTER_AUTH_SECRET=\"$SECRET1\"|g" "$ENV_FILE"
    sed -i "s|PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=\"THAY_BANG_RANDOM_HEX_32_BYTES\"|PAPERCLIP_TOOL_ACTION_SIGNING_SECRET=\"$SECRET2\"|g" "$ENV_FILE"

    # Data dir phải nằm trên ổ Linux (NTFS /mnt/<ổ> không hỗ trợ chmod 0700)
    sed -i "s|^PAPERCLIP_DATA_DIR=.*|PAPERCLIP_DATA_DIR=$HOME/paperclip-data|" "$ENV_FILE"

    # API keys là tuỳ chọn: tài khoản AI (kể cả Claude Pro/Max) kết nối trong UI → Connectors
    sed -i "s|^OPENAI_API_KEY=\"sk-\.\.\.\"|OPENAI_API_KEY=\"\"|" "$ENV_FILE"
    sed -i "s|^ANTHROPIC_API_KEY=\"sk-ant-\.\.\.\"|ANTHROPIC_API_KEY=\"\"|" "$ENV_FILE"

    echo -e "  \033[1;32mCreated .env with auto-generated secrets.\033[0m"
    echo ""
}

env_get() {
    grep -E "^$1=" "$ENV_FILE" | tail -1 | cut -d= -f2- | tr -d '"'
}

env_set() {
    if grep -qE "^$1=" "$ENV_FILE"; then
        sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
    else
        echo "$1=$2" >> "$ENV_FILE"
    fi
}

ensure_data_dir() {
    DATA_DIR=$(env_get PAPERCLIP_DATA_DIR)
    DATA_DIR="${DATA_DIR:-$PROJECT_ROOT/data}"
    mkdir -p "$DATA_DIR"
    echo -e "  Data dir: $DATA_DIR"

    # Container chạy bằng UID/GID của user hiện tại → data dir vẫn thuộc về bạn trên host
    env_set USER_UID "$(id -u)"
    env_set USER_GID "$(id -g)"
}

require_env() {
    if [ ! -f "$ENV_FILE" ]; then
        echo -e "\033[1;31mChưa có .env. Chạy cài đặt lần đầu: ./scripts/run.sh --setup\033[0m"
        echo -e "(Chuyển từ máy khác có backup? Dùng ./scripts/restore.sh để giữ secrets cũ.)"
        exit 1
    fi
}

wait_healthy() {
    echo -e "\033[1;33mWaiting for Paperclip to become healthy...\033[0m"
    for _ in $(seq 1 30); do
        STATUS=$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || echo "missing")
        case "$STATUS" in
            healthy)
                echo -e "  \033[1;32mHealthy.\033[0m"
                return 0 ;;
            unhealthy|missing)
                echo -e "  \033[1;31mContainer is $STATUS. Check: docker compose logs -f\033[0m"
                return 1 ;;
        esac
        sleep 3
    done
    echo -e "  \033[1;33mStill starting after 90s. Check: docker compose logs -f\033[0m"
}

print_running() {
    PORT=$(env_get PAPERCLIP_PORT)
    echo ""
    echo -e "\033[1;32m============================================\033[0m"
    echo -e "\033[1;32m  Paperclip is running!                     \033[0m"
    echo -e "\033[1;32m  Dashboard: http://localhost:${PORT:-3100}           \033[0m"
    echo -e "\033[1;32m============================================\033[0m"
    echo ""
}

print_claude_hint() {
    echo -e "\033[1;36mKết nối Claude Subscription (Pro/Max):\033[0m"
    echo "  Dashboard → Connectors → Anthropic → chọn 'Claude Subscription'"
    echo "  → chạy lệnh Paperclip hiển thị trong container:"
    echo "    docker exec -it -u node $CONTAINER sh -c '<lệnh>'"
    echo "  → đăng nhập trên trình duyệt → bấm Connect"
    echo ""
}

cmd_start() {
    require_env
    echo -e "\033[1;33mStarting Paperclip...\033[0m"
    ensure_data_dir
    docker compose up -d
    wait_healthy
    print_running
}

cmd_setup() {
    echo ""
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;36m  Paperclip - AI Agent Control Plane Setup  \033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    echo ""
    check_docker
    create_env
    cmd_start
    print_claude_hint
}

cmd_refresh() {
    require_env
    echo -e "\033[1;33mPulling latest Paperclip image...\033[0m"
    docker compose pull
    echo -e "\033[1;33mRecreating container (data is kept)...\033[0m"
    ensure_data_dir
    docker compose up -d --force-recreate
    wait_healthy
    print_running
}

case "${1:-}" in
    "")           cmd_start ;;
    --setup)      cmd_setup ;;
    --refresh)    cmd_refresh ;;
    -h|--help)    usage ;;
    *)
        echo -e "\033[1;31mUnknown option: $1\033[0m"
        echo ""
        usage
        exit 1 ;;
esac
