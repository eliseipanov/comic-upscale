

## 🖥️ Instance Specification (stand‑alone markdown)
**File name:** `vast_ai_instance_spec.md`

```markdown
# Vast.ai Instance Specification for Comic Upscale Pipeline

## 1. Desired Hardware Profile
| Resource | Minimum | Recommended | Notes |
|----------|----------|------------|-------|
| **GPU** | Any CUDA‑compatible | **NVIDIA T4** (16 GB VRAM) | Cheapest GPU with enough VRAM for Real‑ESRGAN (x4 model fits comfortably). |
| **vCPU** | 1 | **2** | Improves data‑loading and Flask responsiveness. |
| **RAM** | 8 GB | **12 GB** | Keeps the OS, Python, Docker, and SQLite happy. |
| **Disk** | 20 GB SSD | **30 GB SSD** | 4 000 × (512×768) ≈ 1.5 GB original + 2.5× upscaled ≈ 3 GB; extra space for logs & temp files. |
| **GPU Driver / CUDA** | CUDA 11‑12 (any) | **CUDA 12.1** | Matches the base Docker image (`nvidia/cuda:12.1-runtime-ubuntu22.04`). |

## 2. Pricing & Billing
- **Estimated hourly price:** `$0.040` (T4, 2 vCPU, 12 GB RAM).  
- **Cost ceiling:** `$0.15` → ~3.75 hours of compute time.  
- Turn on **“Terminate on Idle”** (idle = GPU < 5 % for 5 min) to avoid overruns.

## 3. Network & Security Settings
| Setting | Value | Reason |
|---------|-------|--------|
| **Open ports** | `5800/tcp` (Flask UI) <br> `5900/tcp` (optional health API) | Non‑standard ports hide the service from casual scans. |
| **Firewall** | Allow only the two ports above from your IP (or 0.0.0.0/0 if you trust the public). | Minimal exposure. |
| **SSH** | Default `22/tcp` – required for `scp` of the archive. | Use a strong key pair; disable password login. |
| **Environment vars** | `FLASK_SECRET_KEY`, `ADMIN_PASS` passed via `-e`. | No secrets baked into the image. |

## 4. Disk Layout (mounted as Docker volumes)
```
/host
 ├─ /data/input   ← archive is unpacked here (read‑only after upload)
 ├─ /data/output  ← upscaled PNGs (served to UI)
 └─ /data/db      ← SQLite file (progress.db)
```
These directories are **bind‑mounted** into `/app/data/*` inside the container, so data persists even if the container stops.

## 5. Docker Run Command (once the image is built)
```bash
docker run -d \
  --gpus all \
  -p 5800:5800 \
  -p 5900:5900 \
  -v /data/input:/app/data/input:ro \
  -v /data/output:/app/data/output \
  -v /data/db:/app/data/db \
  -e FLASK_SECRET_KEY=$(openssl rand -hex 16) \
  -e ADMIN_PASS="YOUR_SECURE_PASSWORD" \
  --restart unless-stopped \
  yourdockerhubuser/comic_upscale:latest
```
- **`--restart unless-stopped`** ensures the container survives a VM reboot but does **not** auto‑restart after a manual `docker stop`.  
- **Non‑standard ports** (`5800`, `5900`) are mapped to the same numbers inside the container for clarity.

## 6. Automation Scripts (to be placed on the VM)

### `upload.sh`
```bash
#!/usr/bin/env bash
set -e
ARCHIVE=$1          # path to local .tar.gz
REMOTE=ubuntu@${VAST_IP}
ssh $REMOTE "mkdir -p /data/input"
scp $ARCHIVE $REMOTE:/tmp/comics.tar.gz
ssh $REMOTE "tar -xzvf /tmp/comics.tar.gz -C /data/input && rm /tmp/comics.tar.gz"
```

### `run_upscale.sh`
```bash
#!/usr/bin/env bash
ssh $REMOTE "docker exec -d $(docker ps -q -f ancestor=yourdockerhubuser/comic_upscale) \
    python /app/upscale.py \
    --input /app/data/input \
    --output /app/data/output \
    --scale 2.5 \
    --workers 4"
```

### `idle_watchdog.sh`
```bash
#!/usr/bin/env bash
# Run on the VM, not inside Docker
while true; do
  GPU_UTIL=$(docker stats --no-stream --format "{{.CPUPerc}}" $(docker ps -q) | awk '{s+=$1} END {print s/NR}')
  if (( $(echo "$GPU_UTIL < 5.0" | bc -l) )); then
    echo "$(date): GPU idle → stopping container"
    docker stop $(docker ps -q -f ancestor=yourdockerhubuser/comic_upscale)
    exit 0
  fi
  sleep 300   # check every 5 min
done
```

> Add the watchdog to `crontab` (`@reboot /path/idle_watchdog.sh &`) so it starts automatically after a VM boot.

## 7. Verification Checklist (run on the newly created VM)

1. **SSH** into the VM, run `nvidia-smi` → see the T4 listed.  
2. `docker pull yourdockerhubuser/comic_upscale:latest`.  
3. Run the **Docker command** above.  
4. Open the UI: `http://<VAST_IP>:5800` → login with `admin / YOUR_SECURE_PASSWORD`.  
5. Verify that the **progress table** shows 0 jobs initially.  
6. Execute `run_upscale.sh` → watch the **Docker logs** (or UI) for status updates.  
7. After completion, click **Download** on a few rows → ensure the upscaled PNG is correct.  
8. Verify that `idle_watchdog.sh` shuts the container after idle (optional, check `docker ps`).  

---

**That’s the complete spec for the remote instance.**  