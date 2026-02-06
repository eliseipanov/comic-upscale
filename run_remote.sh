#!/bin/bash
# run_remote.sh - Start upscaling + Flask UI on vast.ai
# Usage: ./run_remote.sh [scale] [workers] [model] [face_enhance]
#   Or edit config.sh for defaults

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
else
    echo "ERROR: config.sh not found!"
    exit 1
fi

# Parse args (override config if provided)
SCALE="${1:-${SCALE:-4}}"
WORKERS="${2:-${WORKERS:-1}}"
MODEL="${3:-${MODEL:-RealESRGAN_x4plus}}"
FACE_ENHANCE="${4:-${FACE_ENHANCE:-false}}"

echo "============================================== Comic Upscale - Start =============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Project: $PROJECT_DIR"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo "Face Enhance: $FACE_ENHANCE"
echo ""

if [ "$REMOTE_IP" = "CHANGE_ME" ] || [ "$SSH_PORT" = "CHANGE_ME" ]; then
    echo "[ERROR] Edit config.sh first!"
    exit 1
fi

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create remote start script
REMOTE_SCRIPT="/tmp/start_services_$$.sh"

cat > "$REMOTE_SCRIPT" << REMOTE_EOF
#!/bin/bash
# Auto-generated start script
cd "$PROJECT_DIR"

echo "=== Before restart ==="
ps aux | grep -E 'gunicorn|upscale.py' | grep -v grep || echo 'No existing processes'

echo ""
echo "=== Killing existing processes ==="
pkill -f 'gunicorn.*wsgi:app' 2>/dev/null && echo 'Killed gunicorn' || echo 'No gunicorn to kill'
sleep 1
pkill -f 'upscale.py' 2>/dev/null && echo 'Killed upscale.py' || echo 'No upscale.py to kill'
sleep 1

echo ""
echo "=== Starting Flask UI ==="
nohup $GUNICORN --bind 0.0.0.0:5800 --workers 2 --access-logfile $LOG_DIR/gunicorn.log --error-logfile $LOG_DIR/gunicorn.err wsgi:app > $LOG_DIR/flask.log 2>&1 &
echo "Flask UI started"

echo ""
echo "=== Starting Upscaling ==="
# Build command with face enhance option
if [ "$FACE_ENHANCE" = "true" ]; then
    nohup $PYTHON $PROJECT_DIR/upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale $SCALE --workers $WORKERS --model "$MODEL" --face-enhance > $LOG_DIR/upscale.log 2>&1 &
    echo "Upscaling started (scale=$SCALE, workers=$WORKERS, model=$MODEL, face-enhance=true)"
else
    nohup $PYTHON $PROJECT_DIR/upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale $SCALE --workers $WORKERS --model "$MODEL" > $LOG_DIR/upscale.log 2>&1 &
    echo "Upscaling started (scale=$SCALE, workers=$WORKERS, model=$MODEL)"
fi

echo ""
echo "=== After restart ==="
ps aux | grep -E 'gunicorn|upscale.py' | grep -v grep || echo 'No processes running'

echo ""
echo "=== Last 10 lines of upscale.log ==="
tail -10 $LOG_DIR/upscale.log 2>/dev/null || echo 'No upscale log'
REMOTE_EOF

log_info "Checking SSH..."
if ! ssh -o StrictHostKeyChecking=no -p $SSH_PORT -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo OK" 2>/dev/null; then
    log_error "SSH connection failed!"
    exit 1
fi
log_info "SSH OK"

log_info "Starting Flask UI + Upscaling..."
echo ""

echo "--- Remote Output Start ---"
scp -o StrictHostKeyChecking=no -P $SSH_PORT "$REMOTE_SCRIPT" "$REMOTE_USER@$REMOTE_IP:/tmp/"
SSH_EXIT=$?
if [ $SSH_EXIT -ne 0 ]; then
    log_error "SCP failed!"
    rm -f "$REMOTE_SCRIPT"
    exit 1
fi

ssh -o StrictHostKeyChecking=no -p $SSH_PORT "$REMOTE_USER@$REMOTE_IP" "chmod +x /tmp/start_services_$$.sh && bash /tmp/start_services_$$.sh"
SSH_EXIT=$?

rm -f "$REMOTE_SCRIPT"

echo "--- Remote Output End ---"

if [ $SSH_EXIT -ne 0 ]; then
    log_error "Remote command failed with exit code: $SSH_EXIT"
else
    echo ""
    echo "============================================== Started! =============================================="
fi

echo ""
echo "Logs:"
echo "  Flask: $LOG_DIR/flask.log"
echo "  Upscale: $LOG_DIR/upscale.log"
echo ""
echo "Tail logs remotely:"
echo "  ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_IP 'tail -f $LOG_DIR/upscale.log'"
echo ""
echo "Admin UI: http://$REMOTE_IP:5800 (use SSH tunnel)"
