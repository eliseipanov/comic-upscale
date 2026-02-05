#!/bin/bash
# deploy.sh - Auto deploy to vast.ai
# Usage: ./deploy.sh root@ip:port scale workers model

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
WEIGHTS_DIR="$PROJECT_DIR/weights"
LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "  Comic Upscale - Auto Deploy"
echo "=============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP:$SSH_PORT"
echo "Project: $PROJECT_DIR"
echo "Data: $DATA_DIR"
echo "Weights: $WEIGHTS_DIR"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

if [ -z "$REMOTE_IP" ]; then
    echo "Usage: ./deploy.sh <user@ip[:ssh_port] [ssh_port]> [scale] [workers] [model]"
    exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

SSH_CMD="ssh -o StrictHostKeyChecking=no -p $SSH_PORT"
SCP_CMD="scp -o StrictHostKeyChecking=no -P $SSH_PORT"

log_step "Checking SSH..."
if ! $SSH_CMD -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo OK" 2>/dev/null; then
    echo -e "${RED}[ERROR] Cannot connect!${NC}"
    exit 1
fi

# Create setup script
SETUP_SCRIPT="/tmp/comic_upscale_setup_$$.sh"

cat > "$SETUP_SCRIPT" << 'REMOTE_SCRIPT'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

PROJECT_DIR="/app/comic_upscale"
DATA_DIR="$PROJECT_DIR/data"
WEIGHTS_DIR="$PROJECT_DIR/weights"
INPUT_DIR="$DATA_DIR/input"
OUTPUT_DIR="$DATA_DIR/output"
DB_DIR="$DATA_DIR/db"
LOG_DIR="$DATA_DIR/logs"

echo "============================================== Remote Setup =============================================="

# Install screen
log_step "Installing screen..."
if ! command -v screen &> /dev/null; then
    apt-get update -qq && apt-get install -y -qq screen > /dev/null 2>&1
    log_info "screen installed"
fi

# Create directories inside project
log_step "Creating directories..."
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$DB_DIR" "$LOG_DIR" "$WEIGHTS_DIR"
log_info "  $INPUT_DIR"
log_info "  $OUTPUT_DIR"
log_info "  $DB_DIR"
log_info "  $LOG_DIR"
log_info "  $WEIGHTS_DIR"

# Detect Python
if [ -d "/venv/main" ]; then
    PYTHON_CMD="/venv/main/bin/python"
    PIP_CMD="/venv/main/bin/pip"
elif [ -d "/opt/conda" ]; then
    PYTHON_CMD="/opt/conda/bin/python"
    PIP_CMD="/opt/conda/bin/pip"
else
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
fi

log_info "Python: $PYTHON_CMD"
$PYTHON_CMD --version

# Install dependencies
log_step "Installing Python packages..."
$PIP_CMD install -q realesrgan flask flask-sqlalchemy flask-login gunicorn aiofiles tqdm bcrypt 2>&1 | grep -E "(Successfully|ERROR)" || true

log_step "Verifying Real-ESRGAN..."
$PYTHON_CMD -c "from realesrgan import RealESRGAN; print('Real-ESRGAN: OK')" 2>&1 || log_info "Model will download on first run"

echo ""
echo "============================================== Ready! =============================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Data dir: $DATA_DIR"
echo "Weights: $WEIGHTS_DIR"
echo "Input: $INPUT_DIR"
echo "Output: $OUTPUT_DIR"
echo ""
echo "Run upscaling:"
echo "  cd $PROJECT_DIR"
echo "  source /venv/main/bin/activate"
echo "  python upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale 2.5 --workers 4"
echo ""
REMOTE_SCRIPT

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
    bash /tmp/comic_upscale_setup.sh
"
echo "--- REMOTE OUTPUT END ---"

rm -f "$SETUP_SCRIPT" /tmp/comic_upscale.tar.gz

echo ""
echo "============================================== ✅ Deployment Complete! =============================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Data: $DATA_DIR"
echo "Weights: $WEIGHTS_DIR"
echo ""
echo "Upload images to: $INPUT_DIR"
echo ""
echo "SSH: ssh -p $SSH_PORT $REMOTE_USER@$REMOTE_IP"
echo ""
echo "Run:"
echo "  cd $PROJECT_DIR"
echo "  source /venv/main/bin/activate"
echo "  python upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale $SCALE --workers $WORKERS --model $MODEL"
echo ""
echo "Admin UI: http://$REMOTE_IP:5800"
echo ""
