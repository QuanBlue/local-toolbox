#!/usr/bin/env bash
# ============================================================
# Paperclip Backup Script for Linux / WSL
# Usage: ./scripts/backup.sh [custom_backup_dir]
# Tạo bản backup có timestamp vào folder backups/
# - Đọc PAPERCLIP_DATA_DIR từ .env
# - Tạm dừng container để DB nhất quán, chạy lại sau khi xong
# - Nén bằng tar trong container Paperclip (root) để giữ nguyên owner/permission
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

IMAGE="ghcr.io/paperclipai/paperclip:latest"
ENV_FILE="$PROJECT_ROOT/.env"
DATA_DIR=$(grep -E '^PAPERCLIP_DATA_DIR=' "$ENV_FILE" 2>/dev/null | cut -d= -f2- | tr -d '"')
DATA_DIR="${DATA_DIR:-$PROJECT_ROOT/data}"
BACKUP_DIR="${1:-$PROJECT_ROOT/backups}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="paperclip_backup_$TIMESTAMP"
TARGET_PATH="$BACKUP_DIR/$BACKUP_NAME"

echo ""
echo -e "\033[1;36m========================================\033[0m"
echo -e "\033[1;36m  Paperclip Backup (Linux/WSL)          \033[0m"
echo -e "\033[1;36m========================================\033[0m"
echo ""

if [ ! -d "$DATA_DIR" ] || [ -z "$(ls -A "$DATA_DIR")" ]; then
    echo -e "  \033[1;33mData dir trống hoặc không tồn tại: $DATA_DIR. Nothing to backup.\033[0m"
    exit 0
fi

mkdir -p "$TARGET_PATH"
echo -e "  \033[1;33mData:   $DATA_DIR\033[0m"
echo -e "  \033[1;33mBackup: $TARGET_PATH\033[0m"
echo ""

# Stop container while copying, restart afterwards (also on failure)
WAS_RUNNING=$(docker ps -q -f name=^paperclip-server$)
if [ -n "$WAS_RUNNING" ]; then
    echo -e "  [1/3] Stopping Paperclip container..."
    docker compose stop >/dev/null
    trap 'echo -e "  Restarting Paperclip..."; docker compose start >/dev/null' EXIT
else
    echo -e "  [1/3] Paperclip is not running."
fi

echo -e "  [2/3] Archiving data folder..."
docker run --rm --entrypoint tar \
    -v "$DATA_DIR":/data:ro,z \
    -v "$TARGET_PATH":/backup:z \
    "$IMAGE" czpf /backup/data.tar.gz -C /data .

if [ -f "$ENV_FILE" ]; then
    echo -e "  [3/3] Copying .env configuration..."
    cp "$ENV_FILE" "$TARGET_PATH/.env"
fi

TOTAL_SIZE=$(du -sh "$TARGET_PATH" | cut -f1)

echo ""
echo -e "\033[1;32m========================================\033[0m"
echo -e "\033[1;32m  Backup complete!                      \033[0m"
echo -e "\033[1;32m  Location: $TARGET_PATH                \033[0m"
echo -e "\033[1;32m  Size: $TOTAL_SIZE                     \033[0m"
echo -e "\033[1;32m========================================\033[0m"
echo ""
echo "  To restore, run: ./scripts/restore.sh"
echo ""
