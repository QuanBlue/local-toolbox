#!/usr/bin/env bash
# ============================================================
# Paperclip Restore Script for Linux / WSL
# Usage: ./scripts/restore.sh [backup_folder_name]
# Hoặc: ./scripts/restore.sh (hiển thị danh sách để chọn)
# Khôi phục data.tar.gz vào PAPERCLIP_DATA_DIR của máy hiện tại
# (backup từ máy/user khác vẫn dùng được: data dir + UID được cập nhật theo máy này)
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

IMAGE="ghcr.io/paperclipai/paperclip:latest"
BACKUPS_DIR="$PROJECT_ROOT/backups"
ENV_FILE="$PROJECT_ROOT/.env"

echo ""
echo -e "\033[1;36m========================================\033[0m"
echo -e "\033[1;36m  Paperclip Restore (Linux/WSL)         \033[0m"
echo -e "\033[1;36m========================================\033[0m"
echo ""

if [ ! -d "$BACKUPS_DIR" ]; then
    echo -e "  \033[1;31mNo backups folder found at $BACKUPS_DIR\033[0m"
    exit 1
fi

SELECTED_BACKUP=""
if [ -n "$1" ]; then
    SELECTED_BACKUP="$BACKUPS_DIR/$1"
    if [ ! -d "$SELECTED_BACKUP" ]; then
        echo -e "  \033[1;31mBackup not found: $SELECTED_BACKUP\033[0m"
        exit 1
    fi
else
    # Backup names are timestamped, so reverse sort = newest first
    mapfile -t BACKUPS < <(find -L "$BACKUPS_DIR" -mindepth 1 -maxdepth 1 -type d | sort -r)

    if [ ${#BACKUPS[@]} -eq 0 ]; then
        echo -e "  \033[1;31mNo backups found in $BACKUPS_DIR.\033[0m"
        exit 1
    fi

    echo -e "\033[1;33mAvailable backups:\033[0m"
    INDEX=1
    for b in "${BACKUPS[@]}"; do
        B_NAME=$(basename "$b")
        B_SIZE=$(du -sh "$b" 2>/dev/null | cut -f1)
        echo "  [$INDEX] $B_NAME ($B_SIZE)"
        ((INDEX++))
    done
    echo ""

    read -r -p "Select backup number [default 1]: " USER_CHOICE
    USER_CHOICE="${USER_CHOICE:-1}"

    if ! [[ "$USER_CHOICE" =~ ^[0-9]+$ ]] || [ "$USER_CHOICE" -lt 1 ] || [ "$USER_CHOICE" -gt "${#BACKUPS[@]}" ]; then
        echo -e "  \033[1;31mInvalid selection.\033[0m"
        exit 1
    fi

    SELECTED_BACKUP="${BACKUPS[$((USER_CHOICE-1))]}"
fi

if [ ! -f "$SELECTED_BACKUP/data.tar.gz" ]; then
    echo -e "  \033[1;31mBackup thiếu data.tar.gz: $SELECTED_BACKUP\033[0m"
    exit 1
fi

# Data dir của máy HIỆN TẠI (backup có thể đến từ máy/user khác):
# .env hiện tại nếu có, không thì $HOME/paperclip-data
DATA_DIR=$(grep -E '^PAPERCLIP_DATA_DIR=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"')
DATA_DIR="${DATA_DIR:-$HOME/paperclip-data}"

echo -e "  \033[1;33mRestoring from: $(basename "$SELECTED_BACKUP")\033[0m"
echo -e "  \033[1;33mInto data dir:  $DATA_DIR\033[0m"
echo ""
read -r -p "⚠️  This will OVERWRITE current data. Continue? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "  Restore cancelled."
    exit 0
fi

echo ""
echo -e "  [1/3] Stopping Paperclip container..."
(docker compose down 2>/dev/null || true)

echo -e "  [2/3] Restoring data folder..."
mkdir -p "$DATA_DIR"
docker run --rm --entrypoint sh \
    -v "$DATA_DIR":/data:z \
    -v "$SELECTED_BACKUP":/backup:ro,z \
    "$IMAGE" -c 'find /data -mindepth 1 -delete && tar xzpf /backup/data.tar.gz -C /data'
echo -e "  \033[1;32mData restored.\033[0m"

if [ -f "$SELECTED_BACKUP/.env" ]; then
    echo -e "  [3/3] Restoring .env file (giữ secrets cũ, cập nhật data dir/UID theo máy này)..."
    cp "$SELECTED_BACKUP/.env" "$ENV_FILE"
    for kv in "PAPERCLIP_DATA_DIR=$DATA_DIR" "USER_UID=$(id -u)" "USER_GID=$(id -g)"; do
        key="${kv%%=*}"
        if grep -qE "^$key=" "$ENV_FILE"; then
            sed -i "s|^$key=.*|$kv|" "$ENV_FILE"
        else
            echo "$kv" >> "$ENV_FILE"
        fi
    done
    echo -e "  \033[1;32m.env restored.\033[0m"
fi

echo ""
echo -e "\033[1;32m========================================\033[0m"
echo -e "\033[1;32m  Restore complete!                     \033[0m"
echo -e "\033[1;32m========================================\033[0m"
echo ""

read -r -p "Start Paperclip now? (Y/n): " RESTART_CONFIRM
RESTART_CONFIRM="${RESTART_CONFIRM:-Y}"
if [[ "$RESTART_CONFIRM" =~ ^[yY]$ ]]; then
    docker compose up -d
    echo ""
    echo -e "  \033[1;32mPaperclip is running at http://localhost:3100\033[0m"
fi
