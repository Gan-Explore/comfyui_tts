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
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    libgl1 \
    libglib2.0-0 \
    libavcodec-dev \
    libavformat-dev \
    libavdevice-dev \
    libavfilter-dev \
    libswscale-dev \
    libswresample-dev \
    libavutil-dev \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace

# -------------------------------------------------
# Virtual Environment
# -------------------------------------------------
RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

RUN pip install --upgrade pip setuptools wheel

# -------------------------------------------------
# PyTorch (CUDA 12.4)
# -------------------------------------------------
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# -------------------------------------------------
# Core Dependencies
# -------------------------------------------------
RUN pip install \
    transformers==4.40.2 \
    tokenizers==0.19.1 \
    huggingface-hub==0.36.2 \
    accelerate==0.30.1 \
    sentencepiece \
    safetensors \
    sqlalchemy \
    alembic \
    aiohttp \
    jupyterlab \
    ipykernel \
    matplotlib \
    numpy \
    scipy \
    soundfile \
    librosa \
    av

# -------------------------------------------------
# HuggingFace Cache
# -------------------------------------------------
ENV HF_HOME=/workspace/models/huggingface_cache
ENV TRANSFORMERS_CACHE=/workspace/models/huggingface_cache

EXPOSE 8188
EXPOSE 8888

# -------------------------------------------------
# Startup (NO PIP INSTALLS)
# -------------------------------------------------
CMD bash -c "\
echo 'Starting Jupyter...' && \
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' & \
echo 'Starting ComfyUI...' && \
cd /workspace/runpod-slim/ComfyUI && \
exec python main.py --listen 0.0.0.0 --port 8188 \
"
