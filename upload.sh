#!/bin/bash
# upload.sh - Upload images to vast.ai
# Usage: ./upload.sh ./data/input root@ip:port

set -e

LOCAL_DIR="$1"
SECOND_ARG="$2"
THIRD_ARG="$3"

if [[ "$SECOND_ARG" == *@*:* ]]; then
    REMOTE_FULL="${SECOND_ARG%%:*}"
    SSH_PORT="${SECOND_ARG##*:}"
    REMOTE_USER="${REMOTE_FULL%%@*}"
    REMOTE_IP="${REMOTE_FULL##*@}"
    REMOTE_SUBDIR="${3:-data/input}"
elif [[ "$SECOND_ARG" == *@* ]] && [[ "$THIRD_ARG" =~ ^[0-9]+$ ]]; then
    REMOTE_USER="${SECOND_ARG%%@*}"
    REMOTE_IP="${SECOND_ARG##*@}"
    SSH_PORT="$3"
    REMOTE_SUBDIR="${4:-data/input}"
else
    REMOTE_USER="${SECOND_ARG%%@*}"
    REMOTE_IP="${SECOND_ARG##*@}"
    SSH_PORT="${5:-22}"
    REMOTE_SUBDIR="${3:-data/input}"
fi

REMOTE_DIR="/app/comic_upscale/$REMOTE_SUBDIR"
ARCHIVE_NAME="comic_images_$(date +%Y%m%d_%H%M%S).tar.gz"

echo "=== Comic Upscale Upload ==="
echo "Local: $LOCAL_DIR"
echo "Remote: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Target: $REMOTE_DIR"
echo ""

if [ -z "$REMOTE_IP" ]; then
    echo "Usage: ./upload.sh <local_dir> <user@ip[:ssh_port] [ssh_port]> [subdir]"
    exit 1
fi

GREEN='\033[0;32m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

SSH_CMD="ssh -o StrictHostKeyChecking=no -p $SSH_PORT"
SCP_CMD="scp -o StrictHostKeyChecking=no -P $SSH_PORT"

if [ ! -d "$LOCAL_DIR" ]; then
    echo "ERROR: Local directory not found: $LOCAL_DIR"
    exit 1
fi

IMAGE_COUNT=$(find "$LOCAL_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.bmp" \) | wc -l)
echo "Images: $IMAGE_COUNT"

echo "Creating archive..."
tar -czf "$ARCHIVE_NAME" -C "$(dirname "$LOCAL_DIR")" "$(basename "$LOCAL_DIR")"

echo "Uploading..."
$SCP_CMD "$ARCHIVE_NAME" "$REMOTE_USER@$REMOTE_IP:$ARCHIVE_NAME"

echo "Extracting to $REMOTE_DIR..."
$SSH_CMD "$REMOTE_USER@$REMOTE_IP" "
    mkdir -p $REMOTE_DIR
    tar -xzf $ARCHIVE_NAME -C $(dirname "$REMOTE_DIR")
    rm -f $ARCHIVE_NAME
    echo 'Images in remote dir:'
    find $REMOTE_DIR -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.bmp' \) | wc -l
"

rm -f "$ARCHIVE_NAME"
echo "=== Upload Complete ==="
