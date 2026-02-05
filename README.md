# 🎨 Comic Upscale

Automated comic image upscaling using Real-ESRGAN on free GPU instances (vast.ai).

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [GPU and VRAM Requirements](#gpu-and-vram-requirements)
- [Real-ESRGAN Model Selection](#real-esrgan-model-selection)
- [Two Deployment Options](#two-deployment-options)
  - [Option A: Direct Install (Recommended)](#option-a-direct-install-recommended)
  - [Option B: Docker Container](#option-b-docker-container)
- [Quick Start](#quick-start)
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

| Model | VRAM | Best For |
|-------|------|----------|
| **RealESRGAN_x4plus_anime** | ~4 GB | **🎯 BEST FOR COMICS** - Excellent for anime/comics |
| **RealESRGAN_x4plus** | ~5 GB | General photos, high quality |
| **RealESRGAN_x4plus_anime_6B** | ~3 GB | Lightweight, faster upscaling |
| **realesr-general-x4v3** | ~2 GB | Tiny model, very low VRAM |
| **RealESRGAN_x2plus** | ~4 GB | 2x upscaling (fixed) |
| **RealESRNet_x4plus** | ~4 GB | Basic upscaling (no restoration) |

### Recommended Models for Comics

```
🎯 BEST QUALITY    → RealESRGAN_x4plus_anime
⚡ FASTEST/LIGHT   → realesr-general-x4v3
🔄 2x UPSCALING    → RealESRGAN_x2plus
```

### Using Different Models

```bash
# List all available models
python upscale.py --list-models

# For comics/anime (RECOMMENDED)
python upscale.py --model RealESRGAN_x4plus_anime --input data/input --output data/output --scale 2.5

# Tiny model (low VRAM)
python upscale.py --model realesr-general-x4v3 --input data/input --output data/output --scale 2.5

# 2x upscaling only
python upscale.py --model RealESRGAN_x2plus --input data/input --output data/output --scale 2
```

### Denoising Option (--dn)

The `--dn` parameter controls denoising strength (0-1):

```bash
# No denoising (default)
python upscale.py --dn 0 ...

# Light denoising (prevents over-smoothing)
python upscale.py --dn 0.3 ...

# Strong denoising
python upscale.py --dn 0.7 ...
```

---

## Two Deployment Options

### Option A: Direct Install (Recommended) ✅

**Best for:** Using vast.ai's pre-installed CUDA templates

**Advantages:**
- ✅ Quick setup - no Docker build needed
- ✅ Uses vast.ai's optimized CUDA drivers
- ✅ One-command automated deployment
- ✅ No need for GPU on your local machine

**Steps:**
```bash
# 1. Rent GPU instance on vast.ai (choose CUDA template)
# 2. Get the instance IP

# 3. Deploy everything automatically
chmod +x deploy.sh run_remote.sh
./deploy.sh root@YOUR_INSTANCE_IP

# 4. Upload images and start upscaling
./upload.sh ./data/input root@YOUR_INSTANCE_IP /data/input
./run_remote.sh root@YOUR_INSTANCE_IP 2.5 4 RealESRGAN_x4plus_anime
```

**What deploy.sh does:**
1. SSHs into the instance
2. Uploads project files
3. Creates virtual environment
4. Installs all Python dependencies
5. Sets up directories and environment
6. Generates secure passwords

---

### Option B: Docker Container

**Best for:** Reproducible deployments, multiple instances

**Advantages:**
- ✅ Same environment everywhere
- ✅ Easy to update (pull new image)
- ✅ Isolated from system Python

**Steps:**
```bash
# 1. Build Docker image (on any machine with Docker)
docker build -t yourname/comic_upscale:latest .

# 2. Save and upload to vast.ai (or push to Docker Hub)
docker save yourname/comic_upscale:latest | gzip > comic_upscale.tar.gz
scp comic_upscale.tar.gz root@YOUR_INSTANCE_IP:/tmp/

# 3. On vast.ai instance:
docker load < /tmp/comic_upscale.tar.gz
docker run -d --gpus all -p 5800:5800 -v /data:/data yourname/comic_upscale:latest
```

---

## Quick Start

### Step 1: Rent GPU Instance on vast.ai

1. Go to [vast.ai](https://vast.ai)
2. Choose **"Templates"** → **"CUDA"** (Debian/Ubuntu with NVIDIA drivers pre-installed)
3. Recommended specs:
   - GPU: T4 (16GB VRAM)
   - RAM: 12GB+
   - Disk: 30GB SSD
   - Price: ~$0.04/hr
4. Click "Rent" and wait for status "Running"
5. Copy the IP address

### Step 2: Deploy with One Command

```bash
# Make scripts executable
chmod +x deploy.sh run_remote.sh upload.sh

# Deploy everything (installs Python, dependencies, sets up dirs)
./deploy.sh root@YOUR_INSTANCE_IP

# Upload your comic images
./upload.sh ./data/input root@YOUR_INSTANCE_IP /data/input

# Start upscaling
./run_remote.sh root@YOUR_INSTANCE_IP 2.5 4 RealESRGAN_x4plus_anime
```

### Step 3: Monitor Progress

```bash
# SSH into instance
ssh root@YOUR_INSTANCE_IP

# Check GPU usage
nvidia-smi

# Check upscaling logs
tail -f /data/logs/upscale.log

# Attach to screen session (if using screen)
screen -r upscale

# Access Admin UI
# Open: http://YOUR_INSTANCE_IP:5800
# Login: admin / (password from deploy.sh output)
```

---

## Configuration

### CLI Arguments

```bash
python upscale.py \
    --input /path/to/input           # Input directory (required)
    --output /path/to/output         # Output directory (required)
    --scale 2.5                      # Scale factor: 0.5-4
    --workers 4                     # Number of worker threads
    --model RealESRGAN_x4plus_anime # Model selection
    --dn 0.3                        # Denoising strength 0-1
    --db /path/to/db                # Database path
    --list-models                   # Show available models
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FLASK_SECRET_KEY` | Auto-generated | Secret key for Flask sessions |
| `ADMIN_PASSWORD` | Auto-generated | Admin password |
| `DATABASE_PATH` | `/data/db/upscale.db` | SQLite database location |
| `OUTPUT_DIR` | `/data/output` | Upscaled images output directory |

---

## Usage

### Admin Dashboard

1. Open browser: `http://YOUR_INSTANCE_IP:5800`
2. Login with credentials from `deploy.sh` output
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
scp root@YOUR_INSTANCE_IP:/data/output/*.png ./
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
├── deploy.sh             # ⭐ One-click deploy to vast.ai
├── run_remote.sh         # Run upscaling via SSH
├── upload.sh             # Upload images to server
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
# - Port 5800 already in use
# - GPU not available: nvidia-smi to verify
# - Disk full: df -h
```

### Out of Memory (OOM)

```bash
# Use lighter model with less VRAM
./run_remote.sh root@YOUR_INSTANCE_IP 2.5 2 realesr-general-x4v3

# Or reduce workers
./run_remote.sh root@YOUR_INSTANCE_IP 2.5 2
```

### GPU Not Detected

```bash
# On remote server, verify NVIDIA driver
nvidia-smi

# If not installed:
apt install nvidia-driver-525
systemctl reboot
```

### Login Issues

Check `deploy.sh` output for credentials, or reset by re-running deploy.

---

## License

MIT License - Free for personal and commercial use.

---

## Credits

- [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN) - Amazing upscaling algorithm
- [vast.ai](https://vast.ai) - Affordable GPU instances

---

**Happy Upscaling! 🎨🚀**
