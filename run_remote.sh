#!/bin/bash
# run_remote.sh - Start upscaling + Flask UI on vast.ai
# Usage: ./run_remote.sh [user@ip:port] [scale] [workers] [model]

set -e

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

# Parse args (override config if provided)
REMOTE_USER="${1:-${REMOTE_USER:-root}}"
REMOTE_IP="${2:-${REMOTE_IP:-localhost}}"
SSH_PORT="${3:-${SSH_PORT:-22}}"
SCALE="${4:-${SCALE:-2.5}}"
WORKERS="${5:-${WORKERS:-4}}"
MODEL="${6:-${MODEL:-RealESRGAN_x4plus_anime}}"

echo "============================================== Comic Upscale - Start =============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Project: $PROJECT_DIR"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

if [ "$REMOTE_IP" = "CHANGE_ME" ] || [ "$SSH_PORT" = "CHANGE_ME" ]; then
    echo -e "${RED}[ERROR] Edit config.sh first!${NC}"
    exit 1
fi

GREEN='\033[0;32m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

SSH_CMD="ssh -o StrictHostKeyChecking=no -p $SSH_PORT"

log_info "Checking SSH..."
if ! $SSH_CMD -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo OK" 2>/dev/null; then
    echo "ERROR: Cannot connect to $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
    exit 1
fi

log_info "Starting Flask UI + Upscaling..."

$SSH_CMD "$REMOTE_USER@$REMOTE_IP" "
    cd $PROJECT_DIR
    
    # Start Flask UI with gunicorn
    if ! pgrep -f 'gunicorn.*wsgi:app' > /dev/null; then
        nohup $GUNICORN --bind 0.0.0.0:5800 --workers 2 --access-logfile $LOG_DIR/gunicorn.log --error-logfile $LOG_DIR/gunicorn.err wsgi:app > $LOG_DIR/flask.log 2>&1 &
        echo 'Flask UI started (gunicorn, workers=2)'
    else
        echo 'Flask UI already running'
    fi
    
    # Start upscaling
    if ! pgrep -f 'upscale.py' > /dev/null; then
        nohup $PYTHON upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale $SCALE --workers $WORKERS --model $MODEL > $LOG_DIR/upscale.log 2>&1 &
        echo 'Upscaling started'
    else
        echo 'Upscaling already running'
    fi
    
    echo ''
    echo 'Running processes:'
    ps aux | grep -E 'gunicorn|upscale.py' | grep -v grep
"

echo ""
echo "============================================== ✅ Started! =============================================="
echo ""
echo "Logs:"
echo "  Flask: $LOG_DIR/flask.log"
echo "  Upscale: $LOG_DIR/upscale.log"
echo ""
echo "Tail logs:"
echo "  ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_IP 'tail -f $LOG_DIR/upscale.log'"
echo ""
echo "Admin UI: http://$REMOTE_IP:5800"
echo ""
