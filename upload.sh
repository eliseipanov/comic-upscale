#!/bin/bash
# upload.sh - Upload images to remote server
# Usage: ./upload.sh <local_dir> [user@ip:port]

set -e

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

LOCAL_DIR="${1:-./data/input}"
REMOTE_USER="${2:-${REMOTE_USER:-root}}"
REMOTE_IP="${3:-${REMOTE_IP:-localhost}}"
SSH_PORT="${4:-${SSH_PORT:-22}}"

echo "============================================== Comic Upscale - Upload =============================================="
echo ""
echo "Local: $LOCAL_DIR"
echo "Remote: $INPUT_DIR"
echo "Target: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo ""

if [ "$REMOTE_IP" = "CHANGE_ME" ] || [ "$SSH_PORT" = "CHANGE_ME" ]; then
    echo -e "${RED}[ERROR] Edit config.sh first!${NC}"
    exit 1
fi

if [ ! -d "$LOCAL_DIR" ]; then
    echo "ERROR: Local directory does not exist: $LOCAL_DIR"
    exit 1
fi

FILE_COUNT=$(find "$LOCAL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) | wc -l)
echo "Files to upload: $FILE_COUNT"

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "WARNING: No image files found in $LOCAL_DIR"
    exit 0
fi

SCP_CMD="scp -o StrictHostKeyChecking=no -P $SSH_PORT"

echo ""
echo "Uploading..."
# Only upload image files (case-insensitive)
for ext in jpg jpeg png webp; do
    $SCP_CMD "$LOCAL_DIR"/*."$ext" "$REMOTE_USER@$REMOTE_IP:$INPUT_DIR/" 2>/dev/null || true
done

echo ""
echo "============================================== ✅ Upload Complete! =============================================="
echo ""
echo "Files uploaded to: $INPUT_DIR"
echo ""
