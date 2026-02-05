#!/bin/bash
# deploy.sh - One-click deployment to vast.ai
# Usage: ./deploy.sh <remote_user> <remote_ip> [scale] [workers] [model]

# Don't exit on error - we want to see all errors
set +e

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
    echo "Usage: ./deploy.sh <user@ip> [scale] [workers] [model]"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh root@1.2.3.4"
    echo "  ./deploy.sh root@1.2.3.4 2.5 4 RealESRGAN_x4plus_anime"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check SSH connection
log_step "Checking SSH connection..."
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$REMOTE_USER@$REMOTE_IP" "echo 'SSH OK'" 2>/dev/null; then
    log_error "Cannot connect to $REMOTE_USER@$REMOTE_IP"
    log_info "Make sure:"
    log_info "  1. Instance is running on vast.ai"
    log_info "  2. SSH port (22) is open"
    log_info "  3. You have the correct IP and credentials"
    exit 1
fi
log_info "SSH connection successful!"

# Get CUDA version
log_step "Checking CUDA version..."
CUDA_VERSION=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "nvcc --version 2>/dev/null | grep 'release' | awk '{print \$5}' | cut -d',' -f1" || echo "not found")
log_info "CUDA version: ${CUDA_VERSION:-unknown}"

# Check GPU
log_step "Checking GPU..."
GPU_INFO=$(ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "nvidia-smi --query-gpu=name,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null" || echo "No GPU detected")
log_info "GPU Info: ${GPU_INFO:-No GPU}"

# Create setup script to run on remote
SETUP_SCRIPT="/tmp/comic_upscale_setup_$$.sh"

cat > "$SETUP_SCRIPT" << 'REMOTE_SCRIPT'
#!/bin/bash
# Comic Upscale Setup Script
# Run with: bash /tmp/comic_upscale_setup.sh <scale> <workers> <model>

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "=============================================="
echo "  Comic Upscale - Remote Setup"
echo "=============================================="
echo ""

# Variables
PROJECT_DIR="/app/comic_upscale"
INPUT_DIR="/data/input"
OUTPUT_DIR="/data/output"
DB_DIR="/data/db"
LOG_DIR="/data/logs"
PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')

log_step "System Information:"
log_info "  Python: $PYTHON_VERSION"
log_info "  User: $(whoami)"
log_info "  Working dir: $(pwd)"
echo ""

log_step "Creating directories..."
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$DB_DIR" "$LOG_DIR"
log_info "  Created: $INPUT_DIR"
log_info "  Created: $OUTPUT_DIR"
log_info "  Created: $DB_DIR"
log_info "  Created: $LOG_DIR"
echo ""

# Check and install dependencies
log_step "Installing Python dependencies..."

cd "$PROJECT_DIR"

if [ ! -d ".venv" ]; then
    log_info "Creating virtual environment..."
    python3 -m venv .venv
    if [ $? -ne 0 ]; then
        log_error "Failed to create virtual environment!"
        exit 1
    fi
fi

log_info "Activating virtual environment..."
source .venv/bin/activate

log_info "Upgrading pip..."
pip install --upgrade pip 2>&1 | tail -3

log_info "Installing requirements..."
if ! pip install -r requirements.txt 2>&1 | tee /tmp/pip_install.log; then
    log_error "Failed to install dependencies!"
    echo ""
    echo "=== PIP INSTALL ERRORS ==="
    cat /tmp/pip_install.log
    echo "=========================="
    exit 1
fi

pip list | grep -E "(torch|realesrgan|flask|gunicorn)" || true
echo ""

# Generate secure passwords
log_step "Generating secure credentials..."
FLASK_SECRET=$(openssl rand -hex 32 2>/dev/null || echo "dev_secret_key_change_me")
ADMIN_PASS=$(openssl rand -hex 16 2>/dev/null || echo "admin123")

# Create .env file
log_info "Creating configuration file..."
cat > "$PROJECT_DIR/.env" << EOF
FLASK_SECRET_KEY=$FLASK_SECRET
ADMIN_PASSWORD=$ADMIN_PASS
DATABASE_PATH=$DB_DIR/upscale.db
OUTPUT_DIR=$OUTPUT_DIR
EOF

log_info "Configuration saved to: $PROJECT_DIR/.env"
echo ""

# Test Real-ESRGAN import
log_step "Testing Real-ESRGAN installation..."
python3 -c "from realesrgan import RealESRGAN; print('Real-ESRGAN: OK')" 2>&1 || log_warn "Real-ESRGAN import failed (will download model on first run)"

echo ""
echo "=============================================="
echo "  Setup Complete!"
echo "=============================================="
echo ""
echo "Admin URL: http://\$(hostname -I | cut -d' ' -f1):5800"
echo "Username: admin"
echo "Password: $ADMIN_PASS"
echo ""
echo "Flask Secret: $FLASK_SECRET"
echo ""
echo "Next: Run upscaling with ./run_remote.sh or manually:"
echo "  cd $PROJECT_DIR"
echo "  source .venv/bin/activate"
echo "  python upscale.py --input $INPUT_DIR --output $OUTPUT_DIR --scale ${1:-2.5} --workers ${2:-4}"
echo ""
REMOTE_SCRIPT

# Upload setup script
log_step "Uploading setup script..."
scp -o StrictHostKeyChecking=no "$SETUP_SCRIPT" "$REMOTE_USER@$REMOTE_IP:/tmp/comic_upscale_setup.sh" 2>&1
if [ $? -ne 0 ]; then
    log_error "Failed to upload setup script!"
    exit 1
fi

# Create project tarball
log_step "Creating project archive..."
cd "$PROJECT_DIR"
tar --exclude='.git' --exclude='.venv' --exclude='data/*' --exclude='logs/*' --exclude='*.tar.gz' --exclude='__pycache__' -czf /tmp/comic_upscale.tar.gz . 2>&1
if [ $? -ne 0 ]; then
    log_error "Failed to create archive!"
    exit 1
fi

# Upload project
log_step "Uploading project files (~10MB)..."
scp -o StrictHostKeyChecking=no /tmp/comic_upscale.tar.gz "$REMOTE_USER@$REMOTE_IP:/tmp/" 2>&1
if [ $? -ne 0 ]; then
    log_error "Failed to upload project files!"
    exit 1
fi

# Extract and run setup on remote
log_step "Extracting and running setup on remote..."
echo "--- REMOTE OUTPUT START ---"
ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "
    mkdir -p /app/comic_upscale
    tar -xzf /tmp/comic_upscale.tar.gz -C /app/comic_upscale
    rm /tmp/comic_upscale.tar.gz
    chmod +x /tmp/comic_upscale_setup.sh
    bash /tmp/comic_upscale_setup.sh $SCALE $WORKERS $MODEL
"
REMOTE_EXIT=$?
echo "--- REMOTE OUTPUT END ---"

if [ $REMOTE_EXIT -ne 0 ]; then
    log_error "Remote setup failed with exit code: $REMOTE_EXIT"
    log_info "Check the output above for errors!"
    exit 1
fi

# Cleanup
rm -f "$SETUP_SCRIPT" /tmp/comic_upscale.tar.gz

echo ""
echo "=============================================="
echo "  ✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo ""
echo "1. SSH into the instance:"
echo "   ssh $REMOTE_USER@$REMOTE_IP"
echo ""
echo "2. Run upscaling:"
echo "   cd /app/comic_upscale"
echo "   source .venv/bin/activate"
echo "   python upscale.py --input /data/input --output /data/output --scale $SCALE --workers $WORKERS"
echo ""
echo "3. Or use the helper script:"
echo "   ./run_remote.sh $REMOTE_USER@$REMOTE_IP $SCALE $WORKERS $MODEL"
echo ""
echo "4. Access Admin UI:"
echo "   http://$REMOTE_IP:5800"
echo ""
echo "=============================================="
