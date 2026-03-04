FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------------------------------
# System dependencies
# -------------------------------------------------

RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    ffmpeg \
    sox \
    pkg-config \
    build-essential \
    iputils-ping \
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

# -------------------------------------------------
# Python setup
# -------------------------------------------------

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace

# -------------------------------------------------
# Python virtual environment
# -------------------------------------------------

RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

RUN pip install --upgrade pip setuptools wheel

# -------------------------------------------------
# Install PyTorch (CUDA 12.4)
# -------------------------------------------------

RUN pip install torch torchvision torchaudio \
--index-url https://download.pytorch.org/whl/cu124

# -------------------------------------------------
# Core libraries
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
    jupyter \
    jupyterlab \
    ipykernel \
    matplotlib \
    numpy \
    scipy \
    soundfile \
    librosa \
    av

# -------------------------------------------------
# HuggingFace cache
# -------------------------------------------------

ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface

# -------------------------------------------------
# Ports
# -------------------------------------------------

EXPOSE 8188
EXPOSE 8888

# -------------------------------------------------
# Startup
# -------------------------------------------------

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
