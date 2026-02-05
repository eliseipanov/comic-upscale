#!/bin/bash
# run_remote.sh - Run upscaling + Flask UI on vast.ai
# Usage: ./run_remote.sh root@ip:port scale workers model

set +e

FIRST_ARG="$1"
SECOND_ARG="$2"

if [[ "$FIRST_ARG" == *@*:* ]]; then
    REMOTE_FULL="${FIRST_ARG%%:*}"
    SSH_PORT="${FIRST_ARG##*:}"
    REMOTE_USER="${REMOTE_FULL%%@*}"
    REMOTE_IP="${REMOTE_FULL##*@}"
    SCALE="${3:-2.5}"
    WORKERS="${4:-4}"
    MODEL="${5:-RealESRGAN_x2plus}"
elif [[ "$FIRST_ARG" == *@* ]] && [[ "$SECOND_ARG" =~ ^[0-9]+$ ]]; then
    REMOTE_USER="${FIRST_ARG%%@*}"
    REMOTE_IP="${FIRST_ARG##*@}"
    SSH_PORT="$2"
    SCALE="${3:-2.5}"
    WORKERS="${4:-4}"
    MODEL="${5:-RealESRGAN_x2plus}"
else
    REMOTE_USER="${FIRST_ARG%%@*}"
    REMOTE_IP="${FIRST_ARG##*@}"
    SSH_PORT="${6:-22}"
    SCALE="${2:-2.5}"
    WORKERS="${3:-4}"
    MODEL="${4:-RealESRGAN_x2plus}"
fi

PROJECT_DIR="/app/comic_upscale"
DATA_DIR="$PROJECT_DIR/data"
INPUT_DIR="$DATA_DIR/input"
OUTPUT_DIR="$DATA_DIR/output"
PYTHON="/venv/main/bin/python"
GUNICORN="/venv/main/bin/gunicorn"

echo "============================================== Comic Upscale - Start =============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Project: $PROJECT_DIR"
echo "Python: $PYTHON"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

if [ -z "$REMOTE_IP" ]; then
    echo "Usage: ./run_remote.sh <user@ip[:ssh_port] [ssh_port]> [scale] [workers] [model]"
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
    
    # Start Flask UI with gunicorn (full path)
    if ! pgrep -f 'gunicorn.*wsgi:app' > /dev/null; then
        nohup $GUNICORN --bind 0.0.0.0:5800 --workers 2 --access-logfile $DATA_DIR/logs/gunicorn.log --error-logfile $DATA_DIR/logs/gunicorn.err wsgi:app > $DATA_DIR/logs/flask.log 2>&1 &
        echo 'Flask UI started (gunicorn, workers=2)'
    else
        echo 'Flask UI already running'
    fi
    
    # Start upscaling with full python path
    if ! pgrep -f 'upscale.py' > /dev/null; then
        nohup $PYTHON upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale $SCALE --workers $WORKERS --model $MODEL > $DATA_DIR/logs/upscale.log 2>&1 &
        echo 'Upscaling started'
    else
        echo 'Upscaling already running'
    fi
    
    # Show running processes
    echo ''
    echo 'Running processes:'
    ps aux | grep -E 'gunicorn|upscale.py' | grep -v grep
"

echo ""
echo "============================================== ✅ Started! =============================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Input: $INPUT_DIR"
echo ""
echo "Logs:"
echo "  Flask: $DATA_DIR/logs/flask.log"
echo "  Upscale: $DATA_DIR/logs/upscale.log"
echo ""
echo "Tail logs:"
echo "  ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_IP 'tail -f $DATA_DIR/logs/upscale.log'"
echo ""
echo "Admin UI: http://$REMOTE_IP:5800"
echo ""
