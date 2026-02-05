#!/bin/bash
# deploy.sh - Auto deploy to vast.ai
# Usage: ./deploy.sh [user@ip:port] [scale] [workers] [model]

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
MODEL="${6:-${MODEL:-RealESRGAN_x2plus}}"

LOCAL_DIR="$SCRIPT_DIR"
SETUP_SCRIPT="comic_upscale_setup.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "=============================================="
echo "  Comic Upscale - Auto Deploy"
echo "=============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Project: $PROJECT_DIR"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

if [ "$REMOTE_IP" = "CHANGE_ME" ] || [ "$SSH_PORT" = "CHANGE_ME" ]; then
    echo -e "${RED}[ERROR] Edit config.sh first!${NC}"
    exit 1
fi

SSH_CMD="ssh -o StrictHostKeyChecking=no -p $SSH_PORT"
SCP_CMD="scp -o StrictHostKeyChecking=no -P $SSH_PORT"

log_step "Checking SSH..."
if ! $SSH_CMD -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo OK" 2>/dev/null; then
    echo -e "${RED}[ERROR] Cannot connect to $REMOTE_USER@$REMOTE_IP:$SSH_PORT${NC}"
    exit 1
fi

# Create setup script
cat > "$SETUP_SCRIPT" << EOF
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "\${GREEN}[INFO]\${NC} \$1"; }
log_step() { echo -e "\${BLUE}[STEP]\${NC} \$1"; }

echo "============================================== Remote Setup =============================================="

# Install screen
log_step "Installing screen..."
if ! command -v screen &> /dev/null; then
    apt-get update -qq && apt-get install -y -qq screen > /dev/null 2>&1
    log_info "screen installed"
fi

# Create directories
log_step "Creating directories..."
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$DB_DIR" "$LOG_DIR" "$WEIGHTS_DIR"
log_info "  $INPUT_DIR"
log_info "  $OUTPUT_DIR"
log_info "  $DB_DIR"
log_info "  $LOG_DIR"
log_info "  $WEIGHTS_DIR"

# Install Python packages
log_step "Installing Python packages..."
# Install torch with CUDA first, then torchvision (compatible), then rest
$PIP install -q torch torchvision --index-url https://download.pytorch.org/whl/cu124 2>&1 | grep -E "(Successfully|ERROR)" || true
$PIP install -q realesrgan flask flask-sqlalchemy flask-login gunicorn aiofiles tqdm bcrypt 2>&1 | grep -E "(Successfully|ERROR)" || true

log_step "Verifying installation..."
$PYTHON -c "from realesrgan import RealESRGAN; print('Real-ESRGAN: OK')" 2>&1 || log_info "Model will download on first run"

echo ""
echo "============================================== Ready! =============================================="
echo ""
echo "Run: ./run_remote.sh"
echo ""
EOF

# Upload and run
log_step "Uploading..."
$SCP_CMD "$SETUP_SCRIPT" "$REMOTE_USER@$REMOTE_IP:/tmp/" 2>&1

cd "$LOCAL_DIR"
tar --exclude='.git' --exclude='.venv' --exclude='data/*' --exclude='logs/*' --exclude='*.tar.gz' -czf /tmp/comic_upscale.tar.gz . 2>/dev/null
$SCP_CMD /tmp/comic_upscale.tar.gz "$REMOTE_USER@$REMOTE_IP:/tmp/" 2>&1

log_step "Running remote setup..."
echo "--- REMOTE OUTPUT START ---"
$SSH_CMD "$REMOTE_USER@$REMOTE_IP" "
    mkdir -p $PROJECT_DIR
    tar -xzf /tmp/comic_upscale.tar.gz -C $PROJECT_DIR
    rm /tmp/comic_upscale.tar.gz
    bash /tmp/$SETUP_SCRIPT
"
echo "--- REMOTE OUTPUT END ---"

rm -f "$SETUP_SCRIPT" /tmp/comic_upscale.tar.gz

echo ""
echo "============================================== ✅ Deployment Complete! =============================================="
echo ""
echo "Next: ./run_remote.sh"
echo ""
echo "SSH: ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_IP"
echo "Admin UI: http://$REMOTE_IP:5800"
echo ""
