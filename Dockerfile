FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    ffmpeg \
    sox \
    build-essential \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace

# Persistent model directories
RUN mkdir -p /workspace/models/qwen \
    /workspace/models/openvoice \
    /workspace/models/emotivoice \
    /workspace/models/huggingface_cache

ENV HF_HOME=/workspace/models/huggingface_cache
ENV TRANSFORMERS_CACHE=/workspace/models/huggingface_cache

# Create virtual environment
RUN python -m venv venv
ENV PATH="/workspace/venv/bin:$PATH"

RUN pip install --upgrade pip setuptools wheel

# PyTorch CUDA 12.4
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# Locked dependencies
RUN pip install \
    transformers==4.40.2 \
    tokenizers==0.19.1 \
    huggingface-hub==0.36.2 \
    accelerate==0.30.1 \
    sentencepiece \
    safetensors \
    jupyterlab \
    ipykernel \
    matplotlib \
    numpy \
    scipy \
    soundfile \
    librosa

# Install ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git
WORKDIR /workspace/ComfyUI
RUN pip install -r requirements.txt

# Install Qwen-TTS Node
RUN git clone https://github.com/flybirdxx/ComfyUI-Qwen-TTS.git custom_nodes/ComfyUI-Qwen-TTS

# Install OpenVoice
WORKDIR /workspace
RUN git clone https://github.com/myshell-ai/OpenVoice.git
WORKDIR /workspace/OpenVoice
RUN pip install -r requirements.txt

# Install EmotiVoice
WORKDIR /workspace
RUN git clone https://github.com/netease-youdao/EmotiVoice.git
WORKDIR /workspace/EmotiVoice
RUN pip install -r requirements.txt

WORKDIR /workspace

EXPOSE 8188
EXPOSE 8888

CMD bash -c "\
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --NotebookApp.token='' & \
cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188"
