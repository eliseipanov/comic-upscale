#!/bin/bash
# download_ready.sh - Download upscaled results from server
# Saves to: results/[date_time]/

set -e

# Source config
source config.sh

# Create local results directory with timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
LOCAL_RESULTS_DIR="results/${TIMESTAMP}"
mkdir -p "$LOCAL_RESULTS_DIR"

echo "Downloading upscaled images to: $LOCAL_RESULTS_DIR"
echo "Server: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"

# Download all upscaled images from server
scp -o StrictHostKeyChecking=no -r -P $SSH_PORT $REMOTE_USER@$REMOTE_IP:$OUTPUT_DIR/*.png "$LOCAL_RESULTS_DIR/" 2>/dev/null || true

# Count downloaded files
COUNT=$(ls -1 "$LOCAL_RESULTS_DIR"/*.png 2>/dev/null | wc -l)

echo ""
echo "Downloaded $COUNT images to $LOCAL_RESULTS_DIR"
echo ""

# Show some file sizes
if [ $COUNT -gt 0 ]; then
    echo "Sample file sizes:"
    ls -lh "$LOCAL_RESULTS_DIR"/*.png | head -5
fi
