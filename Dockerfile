# Final Dockerfile for SoulX-Singer with ComfyUI
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

# Create virtual environment
RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# ============================================
# STEP 1: Install base packages (no dependencies)
# ============================================

# Install NumPy 1.24.4 first
RUN pip install --no-cache-dir --no-deps numpy==1.24.4

# Install PyTorch 2.2.0 with CUDA 11.8
RUN pip install --no-cache-dir torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Install comfy-kitchen 0.2.3 (compatible with PyTorch 2.2.0)
RUN pip install --no-cache-dir --no-deps comfy-kitchen==0.2.3

# ============================================
# STEP 2: Install other packages
# ============================================

# Install compatible versions of opencv and scikit-image
RUN pip install --no-cache-dir \
    opencv-python==4.8.1.78 \
    scikit-image==0.21.0

# Copy requirements file
COPY requirements-fixed.txt /tmp/requirements-fixed.txt

# Install requirements without allowing upgrades to pinned packages
RUN pip install --no-cache-dir --no-deps -r /tmp/requirements-fixed.txt

# Install demucs separately (vocal separation)
RUN pip install --no-cache-dir demucs

# ============================================
# STEP 3: Reinstall critical packages (force pin)
# ============================================

# Force reinstall NumPy and comfy-kitchen at the end
RUN pip install --no-cache-dir --force-reinstall --no-deps numpy==1.24.4
RUN pip install --no-cache-dir --force-reinstall --no-deps comfy-kitchen==0.2.3

# ============================================
# STEP 4: Download NLTK data (regex is now installed)
# ============================================
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# ============================================
# STEP 5: Verify installations (skip comfy-kitchen import)
# ============================================
RUN python -c "import numpy as np; print(f'✓ NumPy: {np.__version__}')"
RUN python -c "import torch; print(f'✓ PyTorch: {torch.__version__}'); print(f'✓ CUDA libraries installed')"
RUN pip show comfy-kitchen | grep -E "Version|Location"

# ============================================
# STEP 6: Clean up
# ============================================
RUN rm -rf /root/.cache/pip

# ============================================
# STEP 7: Environment variables
# ============================================
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

# Copy startup script
COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
