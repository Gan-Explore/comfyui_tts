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

RUN pip install --upgrade pip setuptools wheel

# CRITICAL: Install NumPy 1.x FIRST and PIN it
RUN pip install numpy==1.24.4 --no-deps

# PyTorch 2.2.0 with CUDA 11.8
RUN pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Install compatible versions of problem packages
RUN pip install opencv-python==4.8.1.78 scikit-image==0.21.0

# Install comfy-kitchen compatible with PyTorch 2.2.0
RUN pip install comfy-kitchen==0.2.3

# Install core dependencies
RUN pip install \
    soundfile==0.12.1 \
    scipy==1.14.1 \
    librosa==0.10.2 \
    omegaconf==2.3.0 \
    huggingface_hub==0.23.0 \
    safetensors==0.4.5 \
    accelerate==0.33.0 \
    einops==0.8.0 \
    ToJyutping==3.2.0 \
    g2p_en==2.1.0 \
    g2pM==0.1.2.5 \
    nltk==3.8.1 \
    demucs \
    transformers==4.36.2

# Install additional dependencies
RUN pip install \
    tokenizers \
    sentencepiece \
    sqlalchemy \
    alembic \
    aiohttp \
    jupyter \
    jupyterlab \
    ipykernel \
    av \
    gitpython \
    toml \
    tqdm \
    psutil \
    blake3 \
    kornia \
    spandrel \
    pydantic \
    PyOpenGL \
    glfw

# Download NLTK data
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# FINAL PIN: Ensure numpy stays at 1.x
RUN pip install numpy==1.24.4 --force-reinstall --no-deps

# Test NumPy and PyTorch integration
RUN python -c "import numpy as np; import torch; print(f'NumPy: {np.__version__}'); print(f'PyTorch: {torch.__version__}'); print(f'CUDA Available: {torch.cuda.is_available()}')"

# Cache directories
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
