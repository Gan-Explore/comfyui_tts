FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------
# System Dependencies
# -------------------------------------------------
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    ffmpeg \
    sox \
    pkg-config \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# -------------------------------------------------
# Jupyter (separate lightweight env)
# -------------------------------------------------
RUN python3 -m venv /opt/jupyter_env
ENV PATH="/opt/jupyter_env/bin:$PATH"

RUN pip install --upgrade pip
RUN pip install jupyterlab ipykernel matplotlib numpy scipy

# -------------------------------------------------
# HuggingFace Cache (shared)
# -------------------------------------------------
ENV HF_HOME=/workspace/models/huggingface_cache
ENV TRANSFORMERS_CACHE=/workspace/models/huggingface_cache

# -------------------------------------------------
# Expose Ports
# -------------------------------------------------
EXPOSE 8188
EXPOSE 8888

# -------------------------------------------------
# Startup Script
# -------------------------------------------------
CMD bash -c "\
echo 'Starting Jupyter...' && \
/opt/jupyter_env/bin/jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' & \
echo 'Starting ComfyUI...' && \
cd /workspace/runpod-slim/ComfyUI && \
source .venv/bin/activate && \
python main.py --listen 0.0.0.0 --port 8188 \
"
