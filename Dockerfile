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

# Virtual environment
RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install pinned versions
RUN pip install --no-cache-dir --no-deps numpy==1.24.4
RUN pip install --no-cache-dir torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118
RUN pip install --no-cache-dir --no-deps comfy-kitchen==0.2.3

# Install core packages
RUN pip install --no-cache-dir \
    opencv-python==4.8.1.78 \
    scikit-image==0.21.0 \
    soundfile==0.12.1 \
    scipy==1.14.1 \
    librosa==0.10.2 \
    omegaconf==2.3.0 \
    transformers==4.36.2 \
    accelerate==0.33.0 \
    einops==0.8.0 \
    ToJyutping==3.2.0 \
    g2p_en==2.1.0 \
    g2pM==0.1.2.5 \
    nltk==3.8.1 \
    regex==2024.11.6 \
    demucs

# Install Jupyter and dependencies
RUN pip install --no-cache-dir \
    jupyter jupyterlab ipykernel notebook \
    traitlets tornado jupyter-core jupyter-server

# Download NLTK data
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# Force reinstall pinned versions
RUN pip install --no-cache-dir --force-reinstall --no-deps numpy==1.24.4
RUN pip install --no-cache-dir --force-reinstall --no-deps comfy-kitchen==0.2.3

# Clean up
RUN rm -rf /root/.cache/pip

# Environment variables
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
