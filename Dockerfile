# =====================================================
# Comic Upscale Docker Image
# Base: nvidia/cuda:12.1-runtime-ubuntu22.04
# =====================================================

# Build stage
FROM nvidia/cuda:12.1-runtime-ubuntu22.04 AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3.10-dev \
    python3-pip \
    python3-venv \
    git \
    wget \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Create virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip wheel && \
    pip install --no-cache-dir -r requirements.txt

# =====================================================
# Runtime stage (smaller image)
# =====================================================
FROM nvidia/cuda:12.1-runtime-ubuntu22.04

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY . /app/

# Create directories for data persistence
RUN mkdir -p /app/data/input /app/data/output /app/data/db /app/logs

# Create non-root user for security
RUN useradd -m -s /bin/bash appuser && \
    chown -R appuser:appuser /app
USER appuser

# Default environment variables
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=flask.app
ENV FLASK_ENV=production

# Expose ports
EXPOSE 5800 5900

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5800/health')" || exit 1

# Entrypoint - starts both upscale.py and gunicorn
CMD ["sh", "-c", "python /app/upscale.py --input /app/data/input --output /app/data/output --scale 2.5 --workers 4 & gunicorn --bind 0.0.0.0:5800 flask.app:app"]
