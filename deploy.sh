#!/bin/bash
# deploy.sh - One-click deployment to vast.ai
# Usage: ./deploy.sh <remote_user> <remote_ip> <scale> <workers>

set -e

REMOTE_USER="${1:-root}"
REMOTE_IP="${2:-}"
SCALE="${3:-2.5}"
WORKERS="${4:-4}"
MODEL="${5:-RealESRGAN_x4plus_anime}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=============================================="
echo "  Comic Upscale - Auto Deploy to vast.ai"
echo "=============================================="
echo ""
echo "Target: $REMOTE_USER@$REMOTE_IP"
echo "Scale: ${SCALE}x | Workers: $WORKERS | Model: $MODEL"
echo ""

if [ -z "$REMOTE_IP" ]; then
    echo "❌ Error: Remote IP not specified"
    echo ""
    echo "Usage: ./deploy.sh <user> <ip> [scale] [workers] [model]"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh root@1.2.3.4"
    echo "  ./deploy.sh root@1.2.3.4 2.5 4 RealESRGAN_x4plus_anime"
    echo "  ./deploy.sh root@1.2.3.4 2.0 2 RealESRGAN_x4plus"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check SSH connection
log_info "Checking SSH connection to $REMOTE_USER@$REMOTE_IP..."
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo 'SSH OK'" 2>/dev/null; then
    log_error "Cannot connect to $REMOTE_USER@$REMOTE_IP"
    log_info "Make sure:"
    log_info "  1. Instance is running on vast.ai"
    log_info "  2. SSH port (22) is open"
    log_info "  3. You have the correct IP and credentials"
    exit 1
fi

# Get CUDA version
log_info "Checking CUDA version on remote..."
CUDA_VERSION=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "nvcc --version 2>/dev/null | grep 'release' | awk '{print \$5}' | cut -d',' -f1" || echo "not found")
log_info "CUDA version: $CUDA_VERSION"

# Check GPU
log_info "Checking GPU..."
GPU_INFO=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null" || echo "No GPU")
log_info "GPU: $GPU_INFO"

# Create setup script to run on remote
SETUP_SCRIPT="/tmp/comic_upscale_setup_$$.sh"

cat > "$SETUP_SCRIPT" << 'REMOTE_SCRIPT'
#!/bin/bash
set -e

echo "=============================================="
echo "  Setting up Comic Upscale on remote host"
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Variables from main script
PROJECT_DIR="/app/comic_upscale"
INPUT_DIR="/data/input"
OUTPUT_DIR="/data/output"
DB_DIR="/data/db"
LOG_DIR="/data/logs"

log_info "Creating directories..."
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$DB_DIR" "$LOG_DIR"

# Check Python version
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
log_info "Python version: $PYTHON_VERSION"

# Check if poetry is installed, if not use pip venv
if ! command -v poetry &> /dev/null; then
    log_info "Setting up virtual environment with pip..."
    cd "$PROJECT_DIR"
    python3 -m venv .venv
    source .venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
else
    log_info "Using poetry to install dependencies..."
    cd "$PROJECT_DIR"
    poetry install
fi

log_info "Creating directories for data and logs..."
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$DB_DIR" "$LOG_DIR"

# Generate secure passwords
FLASK_SECRET=$(openssl rand -hex 32)
ADMIN_PASS=$(openssl rand -hex 16)

# Create .env file
cat > "$PROJECT_DIR/.env" << EOF
FLASK_SECRET_KEY=$FLASK_SECRET
ADMIN_PASSWORD=$ADMIN_PASS
DATABASE_PATH=$DB_DIR/upscale.db
OUTPUT_DIR=$OUTPUT_DIR
EOF

log_info "Setup complete!"
echo ""
echo "=============================================="
echo "  Credentials (save these!)"
echo "=============================================="
echo "Admin URL: http://\$(hostname -I | cut -d' ' -f1):5800"
echo "Username: admin"
echo "Password: $ADMIN_PASS"
echo ""
echo "Flask Secret: $FLASK_SECRET"
echo "=============================================="
echo ""
echo "Next commands to run upscaling:"
echo "  cd $PROJECT_DIR"
echo "  source .venv/bin/activate"
echo "  python upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale ${1:-2.5} --workers ${2:-4} --model ${3:-RealESRGAN_x4plus_anime}"
echo ""
REMOTE_SCRIPT

# Upload setup script
log_info "Uploading setup script..."
scp -o StrictHostKeyChecking=no "$SETUP_SCRIPT" "$REMOTE_USER@$REMOTE_IP:/tmp/comic_upscale_setup.sh"

# Create project tarball
log_info "Creating project archive..."
cd "$PROJECT_DIR"
tar --exclude='.git' --exclude='.venv' --exclude='data/*' --exclude='logs/*' --exclude='*.tar.gz' -czf /tmp/comic_upscale.tar.gz .

# Upload project
log_info "Uploading project files..."
scp -o StrictHostKeyChecking=no /tmp/comic_upscale.tar.gz "$REMOTE_USER@$REMOTE_IP:/tmp/"

# Extract on remote
log_info "Extracting project on remote..."
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
    mkdir -p /app/comic_upscale
    tar -xzf /tmp/comic_upscale.tar.gz -C /app/comic_upscale
    rm /tmp/comic_upscale.tar.gz
    chmod +x /tmp/comic_upscale_setup.sh
    bash /tmp/comic_upscale_setup.sh $SCALE $WORKERS $MODEL
"

# Cleanup
rm -f "$SETUP_SCRIPT" /tmp/comic_upscale.tar.gz

echo ""
echo "=============================================="
echo "  Deployment Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. SSH into the instance: ssh $REMOTE_USER@$REMOTE_IP"
echo "2. Run upscaling:"
echo "   cd /app/comic_upscale"
echo "   source .venv/bin/activate"
echo "   python upscale.py --input /data/input --output /data/output --scale $SCALE --workers $WORKERS"
echo ""
echo "3. Or create a screen/tmux session for long-running process:"
echo "   screen -S upscale"
echo "   python upscale.py --input /data/input --output /data/output --scale $SCALE --workers $WORKERS"
echo "   # Press Ctrl+A, D to detach"
echo ""
echo "4. Access Admin UI at: http://$REMOTE_IP:5800"
echo ""
