#!/bin/bash
# run_remote.sh - Run upscaling on vast.ai instance via SSH
# Usage: ./run_remote.sh <remote_user> <remote_ip> [scale] [workers] [model]

set +e  # Don't exit on error - show errors

REMOTE_USER="${1:-root}"
REMOTE_IP="${2:-}"
SCALE="${3:-2.5}"
WORKERS="${4:-4}"
MODEL="${5:-RealESRGAN_x4plus_anime}"

echo "=============================================="
echo "  Comic Upscale - Start Upscaling"
echo "=============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

if [ -z "$REMOTE_IP" ]; then
    echo "❌ Error: Remote IP not specified"
    echo ""
    echo "Usage: ./run_remote.sh <user@ip> [scale] [workers] [model]"
    echo "Example: ./run_remote.sh root@1.2.3.4 2.5 4 RealESRGAN_x4plus_anime"
    exit 1
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check connection first
log_info "Checking SSH connection..."
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo 'SSH OK'" 2>/dev/null; then
    log_error "Cannot connect to $REMOTE_USER@$REMOTE_IP"
    exit 1
fi

# Check if screen is available
USE_SCREEN=true
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "command -v screen" 2>/dev/null || USE_SCREEN=false

log_info "Starting upscaling process..."

if [ "$USE_SCREEN" = true ]; then
    log_info "Using screen session for long-running process"
    
    ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
        cd /app/comic_upscale
        source .venv/bin/activate
        
        # Check if screen session already exists
        if screen -ls | grep -q 'upscale'; then
            echo 'Screen session \"upscale\" already running!'
            echo 'Use: screen -r upscale to attach'
        else
            echo 'Starting upscaling in screen session...'
            screen -dmS upscale bash -c '
                cd /app/comic_upscale
                source .venv/bin/activate
                echo \"=== Starting Comic Upscale ===\"
                echo \"Time: \$(date)\"
                python upscale.py \
                    --input /data/input \
                    --output /data/output \
                    --scale $SCALE \
                    --workers $WORKERS \
                    --model $MODEL
                echo \"=== Upscaling Finished ===\"
                echo \"Time: \$(date)\"
                read -p \"Press Enter to close...\" 
            '
            echo 'Screen session \"upscale\" started'
        fi
    "
else
    log_warn "screen not found, using nohup background process"
    
    ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
        cd /app/comic_upscale
        source .venv/bin/activate
        nohup python upscale.py \
            --input /data/input \
            --output /data/output \
            --scale $SCALE \
            --workers $WORKERS \
            --model $MODEL \
            > /data/logs/upscale.log 2>&1 &
        echo 'Upscaling started in background'
        echo 'PID: \$!'
    "
fi

echo ""
echo "=============================================="
echo "  ✅ Upscaling Started!"
echo "=============================================="
echo ""
echo "View logs:"
echo "  ssh $REMOTE_USER@$REMOTE_IP"
echo "  tail -f /data/logs/upscale.log"
echo ""
if [ "$USE_SCREEN" = true ]; then
    echo "Attach to screen:"
    echo "  ssh $REMOTE_USER@$REMOTE_IP"
    echo "  screen -r upscale"
    echo ""
    echo "Detach from screen: Ctrl+A, D"
fi
echo "Admin UI: http://$REMOTE_IP:5800"
echo ""
