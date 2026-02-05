#!/bin/bash
# idle_watchdog.sh - Monitor GPU utilization and auto-stop when idle
# Usage: ./idle_watchdog.sh <remote_user> <remote_ip> [idle_seconds] [gpu_threshold]

set -e

REMOTE_USER="${1:-root}"
REMOTE_IP="${2:-}"
IDLE_THRESHOLD="${3:-300}"  # 5 minutes
GPU_THRESHOLD="${4:-5}"     # 5% GPU utilization
CONTAINER_NAME="comic_upscale"
POLL_INTERVAL=30

echo "=== Comic Upscale Idle Watchdog ==="
echo "Remote: $REMOTE_USER@$REMOTE_IP"
echo "Idle threshold: ${IDLE_THRESHOLD}s"
echo "GPU threshold: ${GPU_THRESHOLD}%"

if [ -z "$REMOTE_IP" ]; then
    echo "Error: Remote IP not specified"
    echo "Usage: ./idle_watchdog.sh <remote_user> <remote_ip> [idle_seconds] [gpu_threshold]"
    exit 1
fi

idle_time=0

while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Checking GPU status..."
    
    # Get GPU utilization
    GPU_OUTPUT=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
        nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null || echo '0'
    " 2>/dev/null)
    
    GPU_UTIL=$(echo "$GPU_OUTPUT" | head -1 | tr -d ' ')
    
    if [ -z "$GPU_UTIL" ]; then
        GPU_UTIL=0
    fi
    
    # Check if container is still running
    CONTAINER_RUNNING=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "docker ps -q --filter name=$CONTAINER_NAME" 2>/dev/null || echo "")
    
    if [ -z "$CONTAINER_RUNNING" ]; then
        echo "Container no longer running, exiting..."
        break
    fi
    
    # Get pending jobs count
    PENDING=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
        docker exec $CONTAINER_NAME python -c '
            import sys
            sys.path.insert(0, \"/app/flask\")
            from flask.app import create_app
            from flask.models import ImageJob
            app = create_app()
            with app.app_context():
                print(ImageJob.query.filter_by(status=\"pending\").count())
        ' 2>/dev/null || echo '-1'
    " 2>/dev/null)
    
    echo "GPU: ${GPU_UTIL}%, Pending jobs: $PENDING"
    
    if [ "$GPU_UTIL" -lt "$GPU_THRESHOLD" ]; then
        idle_time=$((idle_time + POLL_INTERVAL))
        echo "GPU idle for ${idle_time}s / ${IDLE_THRESHOLD}s"
        
        if [ $idle_time -ge $IDLE_THRESHOLD ]; then
            echo "=== Idle threshold reached! Stopping container... ==="
            
            ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
                echo 'Stopping container...'
                docker stop $CONTAINER_NAME
                echo 'Container stopped at \$(date)' >> /app/logs/idle_shutdown.log
            "
            
            echo "=== Watchdog: Done! ==="
            break
        fi
    else
        idle_time=0
        echo "GPU active, resetting idle counter"
    fi
    
    sleep $POLL_INTERVAL
done
