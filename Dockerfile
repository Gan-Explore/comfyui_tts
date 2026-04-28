# Minimal working Dockerfile for SoulX-Singer
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg sox pkg-config build-essential \
    python3.10 python3.10-venv python3.10-dev python3-pip \
    libgl1 libglib2.0-0 libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Python setup
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace

# Virtual environment
RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

RUN pip install --upgrade pip

# 🔥 CRITICAL: Install NumPy 1.x FIRST and PIN it
RUN pip install "numpy==1.24.4"

# PyTorch 2.2.0 with CUDA 11.8
RUN pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Install other dependencies (NumPy is already pinned)
RUN pip install \
    soundfile \
    scipy \
    librosa \
    omegaconf \
    huggingface_hub \
    safetensors \
    accelerate \
    einops

# Text processing
RUN pip install \
    ToJyutping \
    g2p_en \
    g2pM \
    nltk

# Vocal separation (CRITICAL)
RUN pip install demucs

# Transformers (compatible version)
RUN pip install transformers==4.36.2

# Download NLTK data
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# Test NumPy and PyTorch integration
RUN python -c "import numpy as np; import torch; print(f'NumPy: {np.__version__}'); print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}')"

# Pin NumPy again to prevent accidental upgrades
RUN pip install "numpy<2.0.0" --force-reinstall

# Cache directories
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
