## 📦  **Roadmap, Phases, Architecture & Tasks**
**File name:** `comic_upscale_roadmap.md`  
_(Copy‑paste the whole block into your IDE – the LLM “assistant” will treat it as a single source.)_

---  

```markdown
# Comic Upscale – End‑to‑End Roadmap
> Goal: Upscale 2 000–10 000 daughter‑comic images (512×768 → 2×‑2.5×) on a **free** GPU instance (vast.ai), store results, and monitor progress via a tiny Flask admin UI backed by SQLite.

---

## 🎯 High‑Level Objectives
| # | Objective |
|---|-----------|
| 1 | Choose a **free, permissively‑licensed** upscaling model (Real‑ESRGAN). |
| 2 | Build a **single Docker image** that contains: <br>• CUDA runtime + PyTorch <br>• Real‑ESRGAN python wrapper <br>• Async upscaling script <br>• Flask admin UI + SQLite DB |
| 3 | Automate the flow: **SCP → unpack → launch script → queue → upscale → store → UI**. |
| 4 | Keep **cloud cost ≤ 0.15 USD** per full run (stop the instance ASAP). |
| 5 | Produce clean, reproducible artefacts for later LoRA fine‑tuning. |

---

## 🗂️ Development Phases & Milestones

| Phase | Main Deliverable | Rough Duration* | Key Tasks |
|-------|------------------|-----------------|-----------|
| **0 – Prep** | Repo skeleton, local test data | 0.5 d | • Create repo <br>• Collect 20‑30 sample images (photo, anime, 3‑D) |
| **1 – Model & Base Image** | Dockerfile that builds on `nvidia/cuda` and installs Real‑ESRGAN | 1 d | • Choose CUDA version (12.1) <br>• `pip install realesrgan torch torchvision` <br>• Verify `realesrgan.fetch_models()` works |
| **2 – Upscale Engine** | `upscale.py` – async queue, DB write‑back, multi‑worker | 1.5 d | • Design SQLite schema (`ImageJob`) <br>• Implement `save_job / update_job` helpers <br>• Use `asyncio.Queue` + `ThreadPoolExecutor` for GPU work <br>• Add CLI flags (`--scale`, `--workers`, `--input`, `--output`) |
| **3 – Flask Admin** | Minimal dark‑theme admin with login, progress table, download button | 1 d | • Flask‑Login + SQLAlchemy models (`User`, `ImageJob`) <br>• Routes: `/login`, `/`, `/download/<id>` <br>• Non‑standard port **5800** <br>• Simple CSS dark theme |
| **4 – Integration** | Docker‑compose‑like entrypoint that starts both services (Gunicorn + background script) | 0.5 d | • `docker run` command that mounts three persistent volumes (`/data/input`, `/data/output`, `/data/db`) <br>• `CMD ["sh","-c","python /app/upscale.py … & gunicorn …"]` |
| **5 – Deployment Scripts** | Bash wrappers for SCP, start/stop, auto‑shutdown | 0.5 d | • `upload.sh` – compress → scp → remote `tar` <br>• `run_upscale.sh` – `docker exec -d …` <br>• `idle_watchdog.sh` – kills container after 5 min idle |
| **6 – Cost‑Control & Monitoring** | Auto‑shutdown, logging, simple cost estimate | 0.5 d | • Add `docker stats`‑based watchdog (GPU utilization < 5 % → stop) <br>• Log to `/app/logs/upscale.log` <br>• Write a one‑liner to compute USD cost (`$0.04/hr`) |
| **7 – Final QA** | End‑to‑end test on a remote instance, documentation | 0.5 d | • Run on a **T4** instance (≈30 min for 4 000 images) <br>• Verify DB counts, UI refresh, download works <br>• Write `README.md` with one‑click commands |
| **Total** | **≈ 6 days** (including buffer) | | |

*Durations assume a single developer working part‑time; adjust as needed.*

---

## 🏗️ Architecture Overview  

```mermaid
graph TD
    A[Client PC] -->|scp tar.gz| B[vast.ai VM]
    B --> C[Docker Engine]
    C -->|mount| D[/data/input]
    C -->|mount| E[/data/output]
    C -->|mount| F[/data/db]
    subgraph Container
        G[upscale.py] -->|writes| H[SQLite DB]
        G -->|produces| I[Upscaled PNGs]
        J[Flask (Gunicorn)] -->|reads| H
        J -->|serves| K[Admin UI (port 5800)]
    end
    K --> L[User (browser)]
    I -->|download| L
```

*All three volumes (`input`, `output`, `db`) persist across container restarts and VM re‑boots.*  

---

## 📋 Detailed Task List  

| ID | Description | Owner | Status |
|----|-------------|-------|--------|
| **0** | Initialise Git repo (`github.com/you/comic_upscale`) | – | ✅ |
| **1** | Write `Dockerfile` (base: `nvidia/cuda:12.1-runtime-ubuntu22.04`) | – | ✅ |
| **2** | Add `requirements.txt` (torch‑cu118, realesrgan, Flask, SQLAlchemy, gunicorn, aiofiles) | – | ✅ |
| **3** | Implement SQLite schema (`User`, `ImageJob`) in `flask/models.py` | – | ✅ |
| **4** | Build Flask auth (Login, password hash) | – | ✅ |
| **5** | Create basic dark CSS theme (`static/css/dark-theme.css`) | – | ✅ |
| **6** | Write `upscale.py` (async queue, DB callbacks, error handling) | – | ✅ |
| **7** | Add CLI flags & sanity checks (`--scale 2.5`, `--workers 4`) | – | ✅ |
| **8** | Test Real‑ESRGAN locally on a few images (2×, 2.5×) | – | ⬜ |
| **9** | Implement `upload.sh` (tar, scp, remote `mkdir`, `tar -xz`) | – | ✅ |
| **10** | Write `run_upscale.sh` (docker exec background) | – | ✅ |
| **11** | Write `idle_watchdog.sh` (monitor GPU%, stop container) | – | ✅ |
| **12** | Compose entrypoint (`sh -c "python /app/upscale.py … & gunicorn …"`) | – | ✅ |
| **13** | Add non‑standard ports: Flask **5800**, optional REST upscaler **5900** | – | ✅ |
| **14** | Deploy to a **T4** instance on vast.ai (12 GB RAM, 2 vCPU) | – | ⬜ |
| **15** | Run end‑to‑end test (4 000 images) – record time & cost | – | ⬜ |
| **16** | Write README with one‑click commands (`docker run …`) | – | ✅ |
| **17** | Tag Docker image (`yourname/comic_upscale:latest`) and push to Docker Hub | – | ⬜ |
| **18** | (Optional) Add WebSocket progress bar via Flask‑SocketIO | – | ⬜ |

*✅ – Done, 🟡 – In progress, ⬜ – To‑do.*

---

## 📦 Docker Image Summary  

| Layer | Content |
|-------|----------|
| **Base** | `nvidia/cuda:12.1-runtime-ubuntu22.04` (CUDA 12.1, cuDNN 8) |
| **OS Packages** | `python3-pip git ffmpeg libglib2.0-0` |
| **Python** | `torch==2.2.0+cu118`, `torchvision==0.17.0+cu118`, `realesrgan==0.2.5`, `Flask`, `SQLAlchemy`, `gunicorn`, `aiofiles`, `tqdm` |
| **Model Files** | Downloaded on image build (`realesrgan.fetch_models('weights')`) |
| **App Code** | `upscale.py`, `flask/` (templates + static), `db.py`, `utils.py` |
| **Entry Point** | `CMD ["sh","-c","python /app/upscale.py --input /app/data/input --output /app/data/output --scale 2.5 --workers 4 & gunicorn --bind 0.0.0.0:5800 flask.app:app"]` |

---

## 🚨 Security & Port Considerations  

* **Non‑standard ports** – Flask UI runs on **5800**, optional health‑check API on **5900**.  
* **Authentication** – simple username/password stored hashed in SQLite (`admin / <your‑pass>`).  
* **Network exposure** – only open ports `5800` and `5900` in the vast.ai firewall; all other ports blocked.  
* **Secret handling** – keep `FLASK_SECRET_KEY` and admin password as **environment variables** (`-e`) when launching the container; do **not** hard‑code them.  

---

## 📈 Cost‑Control Checklist  

| Item | Recommended Setting |
|------|---------------------|
| GPU type | **T4** (≈ $0.04/hr) – good balance of price vs. VRAM (16 GB) |
| vCPU | 2 |
| RAM | 12 GB |
| Disk | 30 GB SSD (enough for input + upscaled) |
| Auto‑shutdown | Use `idle_watchdog.sh` (stop when GPU < 5 % for 5 min) |
| Billing estimate | 0.5 hr run → **$0.02**; 2 hr run → **$0.08** – well under $0.15 |

---

## 📚 Next Steps  

1. **Fork / clone** the repo and create the `Dockerfile` using the specifications above.  
2. Build locally, verify Real‑ESRGAN works on a handful of images.  
3. Implement `upscale.py` (Phase 2) – test with `--workers 2`.  
4. Add Flask admin (Phase 3) – check DB updates in real time.  
5. Push the image to Docker Hub (or GitHub Packages).  
6. Spin up a **T4** instance on vast.ai, mount volumes, run container.  
7. Run `run_upscale.sh`, watch UI at `http://<IP>:5800`.  
8. Once verified, scale to the full dataset and record cost.  

Good luck – the whole pipeline should be runnable with a **single Docker run command** after the first build! 🎉  

---  

*End of `comic_upscale_roadmap.md`*  

