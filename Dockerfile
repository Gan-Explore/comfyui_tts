# Optimized Dockerfile for SoulX-Singer with ComfyUI
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# System dependencies
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg sox pkg-config build-essential \
    python3.10 python3.10-venv python3.10-dev python3-pip \
    libgl1 libglib2.0-0 libsndfile1 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python setup
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace

# Virtual environment
RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# ============================================
# CRITICAL: Install pinned versions FIRST
# ============================================

# Install NumPy 1.24.4 (compatible with PyTorch 2.2.0)
RUN pip install --no-cache-dir --no-deps numpy==1.24.4

# Install comfy-kitchen 0.2.3 (compatible with PyTorch 2.2.0, no custom_op issue)
RUN pip install --no-cache-dir --no-deps comfy-kitchen==0.2.3

# Install PyTorch 2.2.0 with CUDA 11.8
RUN pip install --no-cache-dir torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Install compatible versions of problem packages
RUN pip install --no-cache-dir \
    opencv-python==4.8.1.78 \
    scikit-image==0.21.0

# Copy requirements-fixed.txt to container
COPY requirements-fixed.txt /tmp/requirements-fixed.txt

# Install all other dependencies from requirements-fixed.txt
RUN pip install --no-cache-dir -r /tmp/requirements-fixed.txt

# Download NLTK data
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# FINAL: Force reinstall pinned versions to ensure no upgrades
RUN pip install --no-cache-dir --force-reinstall --no-deps numpy==1.24.4
RUN pip install --no-cache-dir --force-reinstall --no-deps comfy-kitchen==0.2.3

# Test installations
RUN python -c "import numpy as np; print(f'NumPy: {np.__version__}')"
RUN python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}')"
RUN python -c "import comfy_kitchen; print('comfy-kitchen loaded successfully')"

# Clean up
RUN rm -rf /root/.cache/pip

# Cache directories
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

# Copy startup script
COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
