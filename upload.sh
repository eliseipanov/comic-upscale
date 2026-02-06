#!/bin/bash
# upload.sh - Upload images to server for upscaling
# Usage: ./upload.sh [local_dir] [remote_dir]

set -e

# Source config
source config.sh

# Default directories
LOCAL_DIR="${1:-./input}"
REMOTE_INPUT_DIR="${2:-$INPUT_DIR}"

echo "Uploading images from: $LOCAL_DIR"
echo "To server: $REMOTE_USER@$REMOTE_IP:$REMOTE_INPUT_DIR"

# Create remote directory
ssh -o StrictHostKeyChecking=no -p $SSH_PORT $REMOTE_USER@$REMOTE_IP "mkdir -p $REMOTE_INPUT_DIR"

# Upload all images (case-insensitive)
ssh -o StrictHostKeyChecking=no -p $SSH_PORT $REMOTE_USER@$REMOTE_IP "find $REMOTE_INPUT_DIR -type f -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.jfif' | xargs rm -f 2>/dev/null || true"

# Count local files
LOCAL_COUNT=$(find "$LOCAL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.jfif" \) 2>/dev/null | wc -l)
echo "Found $LOCAL_COUNT images locally"

# Upload using find for case-insensitivity
find "$LOCAL_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.jfif" \) -exec scp -o StrictHostKeyChecking=no -P $SSH_PORT {} $REMOTE_USER@$REMOTE_IP:$REMOTE_INPUT_DIR/ \;

echo ""
echo "Uploaded $LOCAL_COUNT images to server"
