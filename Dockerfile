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

# Install psutil (required for some builds)
RUN pip install psutil

# PyTorch 2.2.0 with CUDA 11.8 (compatible with all SoulX-Singer requirements)
RUN pip install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# Install numpy 1.x (required for compatibility)
RUN pip install "numpy<2.0.0"

# Install vocal separation (CRITICAL for VocalSeparator error)
RUN pip install demucs

# Install dependencies in groups to avoid conflicts
# Group 1: Core audio processing
RUN pip install \
    soundfile==0.12.1 \
    scipy==1.14.1 \
    librosa==0.10.2 \
    omegaconf==2.3.0

# Group 2: Hugging Face and ML core
RUN pip install \
    huggingface_hub==0.23.0 \
    safetensors==0.4.5 \
    accelerate==0.33.0 \
    einops==0.8.0

# Group 3: Text processing (these work well together)
RUN pip install \
    ToJyutping==3.2.0 \
    g2p_en==2.1.0 \
    g2pM==0.1.2.5 \
    nltk==3.8.1

# Group 4: Install transformers WITHOUT conflicting with nemo
RUN pip install transformers==4.36.2

# Group 5: Install NeMo with compatible dependencies
RUN pip install nemo_toolkit[asr]==1.23.0

# Group 6: Audio analysis and processing
RUN pip install \
    praat-parselmouth==0.4.7 \
    pyworld==0.3.5 \
    webrtcvad==2.0.10 \
    pyloudnorm==0.2.0 \
    pretty_midi==0.2.11

# Group 7: Utilities and visualization
RUN pip install \
    tqdm \
    wandb \
    gradio==4.44.1 \
    matplotlib \
    mido \
    numba \
    scikit-learn \
    scikit-image \
    beartype \
    packaging \
    six

# Group 8: LoRA and configuration
RUN pip install \
    loralib==0.1.2 \
    ml-collections \
    fiddle \
    cloudpickle

# Group 9: Additional libraries
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
    toml

# Note: funasr is optional and often causes conflicts - skip it for now
# If you need it, install separately: pip install funasr

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
