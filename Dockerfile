# Use CUDA 11.8 for maximum compatibility with all SoulX-Singer dependencies
FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg sox pkg-config build-essential \
    iputils-ping \
    python3.10 python3.10-venv python3.10-dev python3-pip \
    nodejs npm \
    libgl1 libglib2.0-0 \
    libavcodec-dev libavformat-dev libavdevice-dev \
    libavfilter-dev libswscale-dev libswresample-dev libavutil-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# Python setup
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

WORKDIR /workspace

# Virtual environment
RUN python -m venv /opt/comfy_env
ENV PATH="/opt/comfy_env/bin:$PATH"

RUN pip install --upgrade pip setuptools wheel

# PyTorch 2.2.0 with CUDA 11.8 (compatible with all SoulX-Singer requirements)
RUN pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Flash Attention for RTX 4090 (works with CUDA 11.8)
RUN pip install flash-attn --no-build-isolation

# Install numpy 1.x (required for compatibility)
RUN pip install "numpy<2.0.0"

# Install vocal separation (CRITICAL for VocalSeparator error)
RUN pip install demucs

# Install ALL SoulX-Singer dependencies from your requirements
RUN pip install \
    soundfile==0.13.1 \
    scipy==1.15.3 \
    librosa==0.11.0 \
    omegaconf==2.3.0 \
    huggingface_hub>=0.20.0 \
    safetensors>=0.4.0 \
    accelerate==1.11.0 \
    einops==0.8.2 \
    rotary_embedding_torch==0.8.9 \
    ToJyutping==3.2.0 \
    g2p_en==2.1.0 \
    g2pM==0.1.2.5 \
    funasr==1.3.0 \
    nemo_toolkit[asr]==2.6.1 \
    fiddle>=0.3.0 \
    cloudpickle>=2.0.0 \
    praat-parselmouth==0.4.7 \
    pyworld==0.3.5 \
    webrtcvad==2.0.10 \
    beartype==0.22.9 \
    transformers==4.41.2 \
    tqdm>=4.67.0 \
    wandb>=0.15.0 \
    pretty_midi==0.2.11 \
    ml-collections==1.1.0 \
    loralib==0.1.2 \
    gradio==6.3.0 \
    matplotlib==3.10.8 \
    mido==1.3.3 \
    numba==0.63.1 \
    scikit-learn==1.7.2 \
    scikit-image==0.25.2 \
    pyloudnorm==0.2.0 \
    nltk==3.9.2 \
    packaging==24.2 \
    six==1.17.0

# Additional core libraries
RUN pip install \
    tokenizers==0.19.1 \
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
    torchcodec==0.10.0

# Download NLTK data (required for g2p_en)
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# Set cache directories
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
