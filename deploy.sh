#!/bin/bash
# deploy.sh - Auto deploy to vast.ai with Ollama
# Usage: ./deploy.sh [--with-ollama]
# Options:
#   --with-ollama    Install Ollama + DeepSeek Coder

set -e

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
fi

# Parse arguments
INSTALL_OLLAMA=false
for arg in "$@"; do
    case $arg in
        --with-ollama)
            INSTALL_OLLAMA=true
            shift
            ;;
    esac
done

# Parse other args
REMOTE_USER="${1:-${REMOTE_USER:-root}}"
REMOTE_IP="${2:-${REMOTE_IP:-localhost}}"
SSH_PORT="${3:-${SSH_PORT:-22}}"
SCALE="${4:-${SCALE:-2.5}}"
WORKERS="${5:-${WORKERS:-4}}"
MODEL="${6:-${MODEL:-RealESRGAN_x4plus}}"

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
echo "Ollama: $INSTALL_OLLAMA"
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
log_info "Installing torch 2.2.0 + torchvision 0.17.0 with CUDA..."
$PIP install torch torchvision --index-url https://download.pytorch.org/whl/cu121 2>&1 | grep -E "(Successfully|ERROR)" || true

log_info "Patching basicsr for torchvision compatibility..."
BASICSR_PATH=$($PIP show basicsr 2>/dev/null | grep Location | awk '{print $2}')/basicsr/data/degradations.py 2>/dev/null
if [ -f "$BASICSR_PATH" ]; then
    sed -i 's/from torchvision.transforms.functional_tensor import/from torchvision.transforms.functional import/' "$BASICSR_PATH" 2>/dev/null || true
fi

log_info "Installing realesrgan and other packages..."
$PIP install -q realesrgan flask flask-sqlalchemy flask-login gunicorn aiofiles tqdm bcrypt 2>&1 | grep -E "(Successfully|ERROR)" || true

# Patch after realesrgan installation too
BASICSR_PATH=$($PIP show basicsr 2>/dev/null | grep Location | awk '{print $2}')/basicsr/data/degradations.py 2>/dev/null
if [ -f "$BASICSR_PATH" ]; then
    sed -i 's/from torchvision.transforms.functional_tensor import/from torchvision.transforms.functional import/' "$BASICSR_PATH" 2>/dev/null || true
fi

log_step "Verifying installation..."
$PYTHON -c "from realesrgan import RealESRGANer; print('Real-ESRGAN: OK')" 2>&1 || log_info "Model will download on first run"

# Install Ollama if requested
if [ "$INSTALL_OLLAMA" = true ]; then
    echo ""
    log_step "========================================== Installing Ollama ==========================================="
    
    # Install Ollama
    if ! command -v ollama &> /dev/null; then
        log_info "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh > /dev/null 2>&1
        log_info "Ollama installed"
    else
        log_info "Ollama already installed"
    fi
    
    # Start Ollama service
    log_info "Starting Ollama service..."
    if command -v systemctl &> /dev/null; then
        systemctl start ollama 2>/dev/null || ollama serve &
    else
        ollama serve > /dev/null 2>&1 &
    fi
    sleep 2
    
    # Pull DeepSeek Coder model
    log_info "Pulling DeepSeek Coder model (this may take a few minutes)..."
    ollama pull deepseek-coder 2>&1 | grep -E "(pulling|success|error)" || true
    log_info "DeepSeek Coder ready!"
    
    echo ""
    log_info "Ollama endpoints:"
    log_info "  - Local API: localhost:11434"
    log_info "  - Usage: curl http://localhost:11434/api/generate -d '{...}'"
fi

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
if [ "$INSTALL_OLLAMA" = true ]; then
    echo "Ollama installed! Access via SSH tunnel:"
    echo "  ssh -L 11434:localhost:11434 -p $SSH_PORT $REMOTE_USER@$REMOTE_IP"
fi
echo ""
echo "SSH: ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_IP"
echo "Admin UI: http://$REMOTE_IP:5800"
