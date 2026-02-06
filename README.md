# 🎨 Comic Upscale

Automated comic image upscaling using Real-ESRGAN on GPU instances (vast.ai).

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [GPU and VRAM Requirements](#gpu-and-vram-requirements)
- [Real-ESRGAN Model Selection](#real-esrgan-model-selection)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Usage](#usage)
- [Cost Estimation](#cost-estimation)
- [Troubleshooting](#troubleshooting)

---

## Overview

This project upscales comic images using Real-ESRGAN on GPU instances. It includes:

- **Async upscaling engine** with SQLite job tracking
- **Flask Admin UI** (port 5800) with dark theme
- **Auto-restart watchdog** for reliability
- **One-command deployment** scripts

---

## Features

| Feature | Description |
|---------|-------------|
| 🚀 **Fast Upscaling** | Real-ESRGAN with async queue + tile processing |
| 💾 **SQLite Tracking** | Every image logged with status, progress, timestamps |
| 🌙 **Dark UI** | Beautiful admin dashboard |
| 🔒 **Secure Auth** | Password-protected admin access |
| 💰 **Cost Control** | Only run when needed |

---

## Requirements

- vast.ai account with GPU instance (RTX 3090 recommended)
- SSH access to remote server
- ~30GB disk space

---

## GPU and VRAM Requirements

### Recommended GPU Specifications

| Resource | Minimum | Recommended | Notes |
|----------|---------|-------------|-------|
| **GPU** | Any CUDA | **RTX 3090** (24GB) | Best for Real-ESRGAN |
| **VRAM** | 8GB | **16-24GB** | tile=400 uses ~2.3GB |
| **vCPU** | 1 | **2** | Improves responsiveness |
| **RAM** | 8GB | **16GB** | Keeps system responsive |
| **Disk** | 20GB | **30GB SSD** | For images and models |

### VRAM Usage (with tile=400, FP16)

| GPU | VRAM Used | Max Workers |
|-----|-----------|-------------|
| RTX 3090 (24GB) | ~2.3GB | 4 |
| RTX 3080 (10GB) | ~2.3GB | 3 |
| T4 (16GB) | ~2.3GB | 4 |
| RTX 3070 (8GB) | ~2.3GB | 2 |

**Note:** Tile processing (tile=400) + FP16 dramatically reduces VRAM usage!

---

## Real-ESRGAN Model Selection

| Model | VRAM | Best For |
|-------|------|----------|
| **RealESRGAN_x4plus** | ~2.3GB | **DEFAULT** - General photos, high quality |
| **RealESRGAN_x4plus_anime** | ~2.3GB | Anime/comics |
| **realesr-general-x4v3** | ~1.5GB | Tiny model, very fast |
| **RealESRGAN_x2plus** | ~2GB | 2x upscaling only |

**Current Configuration:** `RealESRGAN_x4plus` with `tile=400` and `FP16` precision.

---

## Deployment

### Step 1: Configure Server

Edit [`config.sh`](config.sh) with your vast.ai instance details:

```bash
REMOTE_USER="root"
REMOTE_IP="77.29.28.253"
SSH_PORT="40417"
```

### Step 2: Deploy to Server

```bash
# Deploy project, install dependencies, setup directories
./deploy.sh

# Upload images to process
./upload.sh

# Start Flask UI + Upscaling
./run_remote.sh

# Download results when done
./download_ready.sh
```

### Step 3: Access Admin UI

Port 5800 is blocked on vast.ai, use SSH tunnel:

```bash
# Local tunnel (run in separate terminal)
./tunnel_flask.sh

# Then open in browser
# http://127.0.0.1:5800
```

**Default Credentials:**
- Username: `admin`
- Password: `admin123`

---

## Configuration

### config.sh Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REMOTE_IP` | - | Server IP address |
| `SSH_PORT` | - | SSH port |
| `SCALE` | `4` | Upscale factor (2-4) |
| `WORKERS` | `1` | Number of workers |
| `MODEL` | `RealESRGAN_x4plus` | Model name |
| `PROJECT_DIR` | `/workspace` | Project path on server |
| `PYTHON` | `/venv/main/bin/python` | Python interpreter |
| `GUNICORN` | `/venv/main/bin/gunicorn` | WSGI server |

### CLI Override

```bash
# Override config with command line arguments
./run_remote.sh 4 1 RealESRGAN_x4plus
# Format: ./run_remote.sh [scale] [workers] [model]
```

---

## Usage

### Upload Images

```bash
./upload.sh
```

Uploads from `data/input` to server's `data/input`.

### Start Upscaling

```bash
./run_remote.sh
```

Starts:
- Flask Admin UI on port 5800
- Upscaling engine processing images from `data/input` to `data/output`

### Monitor Progress

```bash
# Tail upscale log
ssh -p 40417 root@77.29.28.253 'tail -f /workspace/data/logs/upscale.log'

# Check GPU usage
ssh -p 40417 root@77.29.28.253 'nvidia-smi'
```

### Download Results

```bash
./download_ready.sh
```

Downloads completed images from `data/output` to local `data/output`.

### Access Admin UI

```bash
# Create SSH tunnel first
./tunnel_flask.sh

# Then open: http://127.0.0.1:5800
```

---

## Cost Estimation

| GPU | Price/hr | 1000 images | 4000 images |
|-----|----------|-------------|-------------|
| RTX 3090 | ~$0.50 | ~$0.02 | ~$0.08 |
| T4 | ~$0.04 | ~$0.002 | ~$0.008 |

---

## Troubleshooting

### "Process already running" error

Fixed - `./run_remote.sh` now force-restarts processes.

### Out of Memory (OOM)

The tile=400 setting prevents OOM on most GPUs. If still occurring:
- Reduce workers: `./run_remote.sh 4 1`
- Use smaller model: `./run_remote.sh 4 1 realesr-general-x4v3`

### SSH Connection Failed

1. Verify instance is running on vast.ai
2. Check IP and port in [`config.sh`](config.sh)
3. Ensure SSH key is added to instance

### Admin UI Not Loading

Port 5800 requires SSH tunnel:
```bash
./tunnel_flask.sh
```

Then open `http://127.0.0.1:5800`

---

## Project Structure

```
comic_upscale/
├── config.sh              # Centralized configuration
├── deploy.sh              # Deploy to server
├── run_remote.sh          # Start Flask + Upscaling
├── upload.sh              # Upload images
├── download_ready.sh      # Download results
├── tunnel_flask.sh        # SSH tunnel to UI
├── upscale.py             # Upscaling engine
├── webui/
│   ├── app.py            # Flask application
│   ├── models.py         # SQLAlchemy models
│   └── routes.py         # Flask routes
├── Dockerfile            # Docker image
└── requirements.txt     # Dependencies
```

---

## License

MIT License

---

**Happy Upscaling! 🎨🚀**
