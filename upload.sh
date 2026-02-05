#!/bin/bash
# upload.sh - Upload images to vast.ai VM
# Usage: ./upload.sh <local_dir> <remote_user> <remote_ip> <remote_dir>

set -e

LOCAL_DIR="${1:-./data/input}"
REMOTE_USER="${2:-root}"
REMOTE_IP="${3:-}"
REMOTE_DIR="${4:-/app/data/input}"
ARCHIVE_NAME="comic_images_$(date +%Y%m%d_%H%M%S).tar.gz"

echo "=== Comic Upscale Upload ==="
echo "Local dir: $LOCAL_DIR"
echo "Remote: $REMOTE_USER@$REMOTE_IP:$REMOTE_DIR"

if [ -z "$REMOTE_IP" ]; then
    echo "Error: Remote IP not specified"
    echo "Usage: ./upload.sh <local_dir> <remote_user> <remote_ip> <remote_dir>"
    exit 1
fi

# Check if local directory exists
if [ ! -d "$LOCAL_DIR" ]; then
    echo "Error: Local directory does not exist: $LOCAL_DIR"
    exit 1
fi

# Count images
IMAGE_COUNT=$(find "$LOCAL_DIR" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.bmp" \) | wc -l)
echo "Images to upload: $IMAGE_COUNT"

# Create archive
echo "Creating archive: $ARCHIVE_NAME"
tar -czf "$ARCHIVE_NAME" -C "$(dirname "$LOCAL_DIR")" "$(basename "$LOCAL_DIR")"

# Upload via SCP
echo "Uploading to remote server..."
scp -o StrictHostKeyChecking=no "$ARCHIVE_NAME" "$REMOTE_USER@$REMOTE_IP:$ARCHIVE_NAME"

# Extract on remote
echo "Extracting on remote server..."
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
    mkdir -p $REMOTE_DIR
    tar -xzf $ARCHIVE_NAME -C $(dirname "$REMOTE_DIR")
    rm -f $ARCHIVE_NAME
    echo 'Upload complete!'
    echo 'Images in remote dir:'
    find $REMOTE_DIR -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.bmp" \) | wc -l
"

# Cleanup local archive
rm -f "$ARCHIVE_NAME"

echo "=== Upload Complete ==="
