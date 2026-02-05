# 🎨 Comic Upscale

Automated comic image upscaling using Real-ESRGAN on free GPU instances (vast.ai).

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [GPU and VRAM Requirements](#gpu-and-vram-requirements)
- [Real-ESRGAN Model Selection](#real-esrgan-model-selection)
- [Quick Start](#quick-start)
- [Deployment Guide](#deployment-guide)
- [Configuration](#configuration)
- [Usage](#usage)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)

---

## Overview

This project upscales 2,000-10,000 comic images (512×768 → 2×-2.5×) using Real-ESRGAN on a free GPU instance. It includes:

- **Async upscaling engine** with SQLite job tracking
- **Flask Admin UI** (port 5800) with dark theme
- **Auto-stop watchdog** to minimize costs
- **One-command deployment** scripts

---

## Features

| Feature | Description |
|---------|-------------|
| 🚀 **Fast Upscaling** | Real-ESRGAN with async queue + multi-worker processing |
| 💾 **SQLite Tracking** | Every image logged with status, progress, timestamps |
| 🌙 **Dark UI** | Beautiful admin dashboard with real-time stats |
| 🔒 **Secure Auth** | Password-protected admin access |
| 💰 **Cost Control** | Auto-stop when GPU idle (<5% for 5 min) |
| 🐳 **Docker Ready** | Single Docker image for easy deployment |

---

## Requirements

### For Local Development
- Python 3.10+
- NVIDIA GPU with CUDA support (optional for CPU testing)
- 4GB RAM minimum

### For Deployment
- vast.ai account with GPU instance (T4 recommended)
- SSH access to remote server
- ~30GB disk space

---

## GPU and VRAM Requirements

### Recommended GPU Specifications

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **GPU** | Any CUDA-compatible | **NVIDIA T4** (16 GB VRAM) | Best price/performance for Real-ESRGAN. |
| **VRAM** | 8 GB | **12-16 GB** | Comfortable margin for batch processing. |
| **vCPU** | 1 | **2** | Improves data loading and Flask responsiveness. |
| **RAM** | 8 GB | **12 GB** | Keeps OS, Python, Docker, and SQLite happy. |
| **Disk** | 20 GB SSD | **30 GB SSD** | 4,000 × (512×768) ≈ 1.5 GB original + 2.5× upscaled ≈ 3 GB. |
| **CUDA** | 11.8+ | **12.1** | Matches Docker base image (`nvidia/cuda:12.1-runtime-ubuntu22.04`). |

### VRAM Usage by Model

| GPU Model | VRAM | Max Workers | Notes |
|-----------|------|-------------|-------|
| **T4 (16 GB)** | 16 GB | 4 | **Recommended** - plenty of headroom. |
| RTX 3070 | 8 GB | 2-3 | Good budget option. |
| RTX 3080 | 10 GB | 3 | Solid mid-range choice. |
| RTX 4090 | 24 GB | 4+ | Premium performance. |
| A100 (40 GB) | 40 GB | 4+ | Enterprise-grade. |

---

## Real-ESRGAN Model Selection

Real-ESRGAN offers multiple models optimized for different image types. Choose based on your content:

| Model Name | Best For | VRAM | Quality |
|------------|----------|-------|---------|
| **RealESRGAN_x4plus** | General photos, realistic images | ~5 GB | High |
| **RealESRGAN_x4plus_anime** | Anime, comics, cartoons | ~4 GB | Excellent for stylized |
| **RealESRGAN_x4plus_anime_6B** | Lightweight anime/comics | ~3 GB | Good, faster |
| **RealESRNet_x4plus** | Basic upscaling (no restoration) | ~4 GB | Standard |

### Recommended Models for Comics

For comic book images, we recommend:

```
🎯 Best Quality → RealESRGAN_x4plus_anime
⚡ Faster Speed  → RealESRGAN_x4plus_anime_6B
📸 Mixed Content → RealESRGAN_x4plus
```

### Changing the Model

Edit `upscale.py` or pass the `--model` argument:

```bash
# For anime/comics (recommended)
python upscale.py --model RealESRGAN_x4plus_anime --input data/input --output data/output --scale 2.5

# For general images
python upscale.py --model RealESRGAN_x4plus --input data/input --output data/output --scale 2.5

# Lightweight mode (less VRAM)
python upscale.py --model RealESRGAN_x4plus_anime_6B --input data/input --output data/output --scale 2.5
```

---

## Quick Start

### Step 1: Clone and Setup

```bash
# Clone repository
git clone https://github.com/yourname/comic_upscale.git
cd comic_upscale

# Create virtual environment
python3 -m venv .venv
source .venv/bin activate  # Linux/Mac
# OR: .venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt
```

### Step 2: Test Locally (Optional)

```bash
# Create test directories
mkdir -p data/input data/output data/db logs

# Add test images to data/input/
# Supports: PNG, JPG, JPEG, BMP, TIFF, WebP

# Run upscaling locally
python upscale.py \
    --input data/input \
    --output data/output \
    --scale 2.5 \
    --workers 4

# View logs
cat logs/upscale.log
```

### Step 3: Build Docker Image

```bash
# Build the image
docker build -t yourname/comic_upscale:latest .

# Verify image exists
docker images | grep comic_upscale
```

### Step 4: Push to Docker Hub (Optional)

```bash
# Login to Docker Hub
docker login

# Push image
docker tag yourname/comic_upscale:latest yourname/comic_upscale:latest
docker push yourname/comic_upscale:latest
```

---

## Deployment Guide

### Step 1: Rent GPU Instance on vast.ai

1. Go to [vast.ai](https://vast.ai)
2. Search for **T4** GPU instances
3. Recommended specs:
   - GPU: T4 (16GB VRAM)
   - RAM: 12GB+
   - Disk: 30GB SSD
   - Price: ~$0.04/hr
4. Click "Rent"

### Step 2: Connect to Instance

```bash
# Get instance IP from vast.ai dashboard
ssh root@YOUR_INSTANCE_IP

# Update system
apt update && apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sh

# Add user to docker group
usermod -aG docker $USER

# Verify Docker works
docker run hello-world
```

### Step 3: Deploy Container

```bash
# On YOUR LOCAL MACHINE, run deployment script
chmod +x upload.sh run_upscale.sh idle_watchdog.sh

# Upload images
./upload.sh ./data/input root@YOUR_INSTANCE_IP /app/data/input

# Start upscaling container
./run_upscale.sh root@YOUR_INSTANCE_IP 2.5 4
```

### Step 4: Monitor Progress

```bash
# SSH into instance
ssh root@YOUR_INSTANCE_IP

# Check container status
docker ps

# View logs
docker logs -f comic_upscale

# Check GPU usage
nvidia-smi

# Access Admin UI
# Open browser: http://YOUR_INSTANCE_IP:5800
# Login: admin / (check output of run_upscale.sh for password)
```

---

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_SECRET_KEY` | Auto-generated | Secret key for Flask sessions |
| `ADMIN_PASSWORD` | Auto-generated | Admin password (change in production!) |
| `DATABASE_PATH` | `/app/data/db/upscale.db` | SQLite database location |
| `OUTPUT_DIR` | `/app/data/output` | Upscaled images output directory |
| `CUDA_VISIBLE_DEVICES` | `0` | GPU device ID |

### CLI Arguments (upscale.py)

```bash
python upscale.py \
    --input /path/to/input      # Input directory (required)
    --output /path/to/output    # Output directory (required)
    --scale 2.5                 # Scale factor: 2, 2.5, 4
    --workers 4                 # Number of worker threads
    --model RealESRGAN_x4plus_anime  # Model selection
    --db /path/to/db            # Database path
```

---

## Usage

### Admin Dashboard

1. Open browser: `http://YOUR_INSTANCE_IP:5800`
2. Login with credentials from `run_upscale.sh` output
3. View:
   - Total images count
   - Pending/Processing/Completed/Failed stats
   - Overall progress bar
   - Recent jobs table with download links

### API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/` | Admin dashboard (requires login) |
| `/login` | Login page |
| `/logout` | Logout |
| `/download/<job_id>` | Download upscaled image |
| `/api/status` | JSON status of all jobs |
| `/api/stats` | JSON statistics |
| `/health` | Health check (no auth) |

### Download Upscaled Images

```bash
# Method 1: Via Admin UI
# Click "Download" button next to completed job

# Method 2: Via SCP
scp root@YOUR_INSTANCE_IP:/app/data/output/*.png ./
```

---

## Cost Estimation

| Scenario | Images | Time | Cost |
|----------|--------|------|------|
| Small batch | 100 | ~2 min | <$0.01 |
| Medium batch | 1,000 | ~20 min | ~$0.02 |
| Large batch | 4,000 | ~80 min | ~$0.08 |
| Full dataset | 10,000 | ~200 min | ~$0.15 |

**Note:** Actual cost depends on GPU type and instance price.

### Cost Control Features

- **Auto-stop watchdog**: Shuts down when GPU <5% for 5 minutes
- **Manual stop**: `docker stop comic_upscale`
- **Cost per hour**: ~$0.04 (T4 on vast.ai)

---

## Project Structure

```
comic_upscale/
├── .venv/                  # Python virtual environment
├── flask/
│   ├── app.py             # Flask application factory
│   ├── models.py          # SQLAlchemy models (User, ImageJob)
│   ├── routes.py          # Flask routes
│   ├── static/
│   │   └── css/
│   │       └── dark-theme.css  # Dark theme
│   └── templates/
│       ├── login.html     # Login page
│       └── dashboard.html # Admin dashboard
├── data/
│   ├── input/             # Input images (mount to container)
│   ├── output/           # Upscaled images
│   └── db/               # SQLite database
├── logs/                 # Application logs
├── upscale.py            # Async upscaling engine
├── upload.sh             # Upload images to server
├── run_upscale.sh        # Start container on server
├── idle_watchdog.sh      # Monitor and auto-stop
├── Dockerfile            # Docker image definition
├── requirements.txt      # Python dependencies
└── README.md            # This file
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs comic_upscale

# Common issues:
# - Port 5800 already in use: change port mapping in run_upscale.sh
# - GPU not available: nvidia-smi to verify
# - Disk full: df -h
```

### Out of Memory (OOM)

```bash
# Reduce workers in run_upscale.sh
./run_upscale.sh root@YOUR_INSTANCE_IP 2.5 2  # Use 2 workers instead of 4

# Or use smaller scale
./run_upscale.sh root@YOUR_INSTANCE_IP 2.0 4

# Or use lighter model
./run_upscale.sh root@YOUR_INSTANCE_IP 2.5 4 --model RealESRGAN_x4plus_anime_6B
```

### GPU Not Detected

```bash
# On remote server, verify NVIDIA driver
nvidia-smi

# If not installed:
apt install nvidia-driver-525

# Restart Docker
systemctl restart docker

# Re-run container with --gpus all
```

### Login Issues

```bash
# Reset admin password
# Edit run_upscale.sh to set ADMIN_PASSWORD=your_new_password
# Stop and restart container
docker stop comic_upscale
./run_upscale.sh root@YOUR_INSTANCE_IP 2.5 4
```

---

## Security Notes

⚠️ **Important for Production:**

1. Change default credentials before deployment
2. Use strong `FLASK_SECRET_KEY`
3. Restrict firewall to only ports 5800, 5900
4. Use HTTPS with a reverse proxy (nginx)
5. Don't expose admin UI to public internet

---

## License

MIT License - Free for personal and commercial use.

---

## Credits

- [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) - Amazing upscaling algorithm
- [vast.ai](https://vast.ai) - Affordable GPU instances

---

**Happy Upscaling! 🎨🚀**
