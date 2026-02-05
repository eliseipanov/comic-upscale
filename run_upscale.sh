#!/bin/bash
# run_upscale.sh - Start the upscaling process on vast.ai VM
# Usage: ./run_upscale.sh <remote_user> <remote_ip> <scale> <workers>

set -e

REMOTE_USER="${1:-root}"
REMOTE_IP="${2:-}"
SCALE="${3:-2.5}"
WORKERS="${4:-4}"
CONTAINER_NAME="comic_upscale"

echo "=== Comic Upscale - Start ==="
echo "Remote: $REMOTE_USER@$REMOTE_IP"
echo "Scale: ${SCALE}x"
echo "Workers: $WORKERS"

if [ -z "$REMOTE_IP" ]; then
    echo "Error: Remote IP not specified"
    echo "Usage: ./run_upscale.sh <remote_user> <remote_ip> <scale> <workers>"
    exit 1
fi

# Check if container is already running
EXISTING=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "docker ps -q --filter name=$CONTAINER_NAME" 2>/dev/null || echo "")

if [ -n "$EXISTING" ]; then
    echo "Container already running: $CONTAINER_NAME"
    echo "Stopping existing container..."
    ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "docker stop $CONTAINER_NAME 2>/dev/null || true"
fi

# Run the container detached
echo "Starting container..."
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
    docker run -d \
        --name $CONTAINER_NAME \
        --gpus all \
        -p 5800:5800 \
        -p 5900:5900 \
        -v /app/data/input:/app/data/input \
        -v /app/data/output:/app/data/output \
        -v /app/data/db:/app/data/db \
        -v /app/logs:/app/logs \
        -e FLASK_SECRET_KEY=\$(openssl rand -hex 32) \
        -e ADMIN_PASSWORD=\$(openssl rand -hex 16) \
        -e CUDA_VISIBLE_DEVICES=0 \
        yourname/comic_upscale:latest \
        python /app/upscale.py \
            --input /app/data/input \
            --output /app/data/output \
            --scale $SCALE \
            --workers $WORKERS
"

echo "Container started!"
echo ""
echo "=== Next Steps ==="
echo "1. Wait ~30 seconds for the service to start"
echo "2. Open: http://$REMOTE_IP:5800"
echo "3. Login with: admin / <password>"
echo ""
echo "Check logs with: docker logs -f $CONTAINER_NAME"
