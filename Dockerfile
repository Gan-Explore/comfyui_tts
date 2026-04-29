# Self-contained Dockerfile with known working ComfyUI version
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# System dependencies
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg sox pkg-config build-essential \
    python3.10 python3.10-venv python3.10-dev python3-pip \
    python-is-python3 \
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

# Install NumPy 1.24.4 first
RUN pip install --no-cache-dir --no-deps numpy==1.24.4

# Install PyTorch 2.2.0 with CUDA 11.8
RUN pip install --no-cache-dir torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Clone a known working version of ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI && \
    cd /workspace/ComfyUI && \
    git checkout 68e2b70

# Install ComfyUI requirements
RUN pip install --no-cache-dir -r /workspace/ComfyUI/requirements.txt || true

# Install SoulX-Singer dependencies
RUN pip install --no-cache-dir \
    ToJyutping==3.2.0 \
    g2p_en==2.1.0 \
    g2pM==0.1.2.5 \
    demucs \
    transformers==4.36.2 \
    accelerate==0.33.0 \
    einops==0.8.0 \
    soundfile==0.12.1 \
    scipy==1.14.1 \
    librosa==0.10.2 \
    omegaconf==2.3.0 \
    opencv-python==4.8.1.78 \
    scikit-image==0.21.0 \
    nltk==3.8.1 \
    regex==2024.11.6 \
    jupyter jupyterlab ipykernel

# Download NLTK data
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# Final NumPy pin
RUN pip install --no-cache-dir --force-reinstall --no-deps numpy==1.24.4

# Clean up
RUN rm -rf /root/.cache/pip

# Setup working directories
RUN mkdir -p /workspace/runpod-slim/{models,input,output,custom_nodes}

# Environment variables
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
