#!/bin/bash
# run_remote.sh - Run upscaling on vast.ai instance via SSH
# Usage: ./run_remote.sh <remote_user> <remote_ip> [scale] [workers] [model]

set -e

REMOTE_USER="${1:-root}"
REMOTE_IP="${2:-}"
SCALE="${3:-2.5}"
WORKERS="${4:-4}"
MODEL="${5:-RealESRGAN_x4plus_anime}"

if [ -z "$REMOTE_IP" ]; then
    echo "Usage: ./run_remote.sh <user@ip> [scale] [workers] [model]"
    echo "Example: ./run_remote.sh root@1.2.3.4 2.5 4 RealESRGAN_x4plus_anime"
    exit 1
fi

echo "Starting upscaling on $REMOTE_USER@$REMOTE_IP..."
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

# SSH command to run upscaling
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
    cd /app/comic_upscale
    source .venv/bin/activate
    
    # Create screen session for long-running process
    if command -v screen &> /dev/null; then
        screen -dmS upscale python upscale.py \
            --input /data/input \
            --output /data/output \
            --scale $SCALE \
            --workers $WORKERS \
            --model $MODEL
        echo 'Upscaling started in screen session \"upscale\"'
        echo ''
        echo 'Commands to manage:'
        echo '  screen -r upscale    # Attach to session'
        echo '  screen -ls          # List sessions'
        echo '  screen -S upscale -X quit  # Kill session'
    else
        echo 'Starting upscaling in background...'
        nohup python upscale.py \
            --input /data/input \
            --output /data/output \
            --scale $SCALE \
            --workers $WORKERS \
            --model $MODEL \
            > /data/logs/upscale.log 2>&1 &
        echo 'Upscaling started in background'
        echo 'Check logs: tail -f /data/logs/upscale.log'
    fi
"

echo ""
echo "Upscaling process started!"
echo "Access Admin UI: http://$REMOTE_IP:5800"
