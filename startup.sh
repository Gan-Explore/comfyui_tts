#!/bin/bash

set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CUSTOM="$BASE/custom_nodes"
TTS="$BASE/tts"
CACHE="$BASE/model_cache"
PYTHON="/opt/comfy_env/bin/python"

echo "========================================"
echo "AI CREATION STACK BOOT"
echo "ComfyUI + Nodes + TTS + GPU + Cache"
echo "========================================"

mkdir -p $BASE

# -------------------------------------------------
# GPU OPTIMIZATION
# -------------------------------------------------

echo "Configuring GPU environment..."

export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
export CUDA_DEVICE_MAX_CONNECTIONS=1
export CUDA_LAUNCH_BLOCKING=0
export TORCH_CUDNN_V8_API_ENABLED=1

# -------------------------------------------------
# MODEL CACHE MANAGER
# -------------------------------------------------

echo "Initializing model cache..."

mkdir -p $CACHE
mkdir -p $CACHE/huggingface
mkdir -p $CACHE/torch
mkdir -p $CACHE/diffusers
mkdir -p $CACHE/tts

export HF_HOME=$CACHE/huggingface
export TRANSFORMERS_CACHE=$CACHE/huggingface
export TORCH_HOME=$CACHE/torch
export XDG_CACHE_HOME=$CACHE

# cleanup partial downloads
find $CACHE -name "*.lock" -delete || true

# -------------------------------------------------
# DIRECTORY STRUCTURE
# -------------------------------------------------

mkdir -p $BASE/models
mkdir -p $BASE/models/checkpoints
mkdir -p $BASE/models/loras
mkdir -p $BASE/models/controlnet
mkdir -p $BASE/models/vae
mkdir -p $BASE/models/upscale_models
mkdir -p $BASE/models/clip

mkdir -p $CUSTOM
mkdir -p $BASE/input
mkdir -p $BASE/output
mkdir -p $BASE/user

mkdir -p $BASE/audio_projects

mkdir -p $TTS
mkdir -p $TTS/models
mkdir -p $TTS/cache

# -------------------------------------------------
# INSTALL COMFYUI
# -------------------------------------------------

if [ ! -f "$COMFY/main.py" ]; then

    echo "Installing fresh ComfyUI..."

    rm -rf $COMFY
    cd $BASE
    git clone https://github.com/comfyanonymous/ComfyUI.git

    cd $COMFY

    $PYTHON -m pip install --upgrade pip
    $PYTHON -m pip install -r requirements.txt

fi

# -------------------------------------------------
# LINK PERSISTENT DIRECTORIES
# -------------------------------------------------

echo "Linking persistent folders..."

rm -rf $COMFY/models || true
rm -rf $COMFY/custom_nodes || true
rm -rf $COMFY/input || true
rm -rf $COMFY/output || true
rm -rf $COMFY/user || true

ln -s $BASE/models $COMFY/models
ln -s $CUSTOM $COMFY/custom_nodes
ln -s $BASE/input $COMFY/input
ln -s $BASE/output $COMFY/output
ln -s $BASE/user $COMFY/user

# -------------------------------------------------
# INSTALL COMFYUI MANAGER
# -------------------------------------------------

if [ ! -d "$CUSTOM/ComfyUI-Manager" ]; then
    echo "Installing ComfyUI Manager..."
    cd $CUSTOM
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
fi

# -------------------------------------------------
# NODE AUTO INSTALLER
# -------------------------------------------------

install_node () {

NODE=$1
REPO=$2

if [ ! -d "$CUSTOM/$NODE" ]; then
    echo "Installing node: $NODE"
    cd $CUSTOM
    git clone $REPO
fi

}

install_node "ComfyUI-VideoHelperSuite" "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
install_node "ComfyUI-Impact-Pack" "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"

# -------------------------------------------------
# NODE DEPENDENCIES
# -------------------------------------------------

echo "Installing node dependencies..."

for dir in $CUSTOM/*; do

    if [ -f "$dir/requirements.txt" ]; then
        echo "Installing deps for $(basename $dir)"
        $PYTHON -m pip install -r "$dir/requirements.txt" || true
    fi

    if [ -f "$dir/install.py" ]; then
        echo "Running install.py for $(basename $dir)"
        $PYTHON "$dir/install.py" || true
    fi

done

# -------------------------------------------------
# GPU ACCELERATION
# -------------------------------------------------

if ! $PYTHON -c "import xformers" 2>/dev/null; then
    echo "Installing xFormers..."
    $PYTHON -m pip install xformers --extra-index-url https://download.pytorch.org/whl/cu124 || true
fi

# -------------------------------------------------
# VERIFY COMFYUI DEPENDENCIES
# -------------------------------------------------

if ! $PYTHON -c "import aiohttp" 2>/dev/null; then
    echo "Repairing ComfyUI dependencies..."
    cd $COMFY
    $PYTHON -m pip install -r requirements.txt
fi

# -------------------------------------------------
# INSTALL TTS ENGINES
# -------------------------------------------------

echo "Preparing TTS engines..."

# ---------- OpenVoice ----------

if [ ! -d "$TTS/OpenVoice" ]; then

    echo "Installing OpenVoice..."

    cd $TTS
    git clone https://github.com/myshell-ai/OpenVoice.git

    cd OpenVoice
    $PYTHON -m pip install -r requirements.txt

fi

# ---------- EmotiVoice ----------

if [ ! -d "$TTS/EmotiVoice" ]; then

    echo "Installing EmotiVoice..."

    cd $TTS
    git clone https://github.com/netease-youdao/EmotiVoice.git

    cd EmotiVoice
    $PYTHON -m pip install -r requirements.txt || true

fi

# placeholder for Qwen TTS models
mkdir -p $TTS/qwen_models

# -------------------------------------------------
# INSTALL AUDIO TOOLING
# -------------------------------------------------

if ! command -v ffmpeg &> /dev/null
then
    echo "Installing FFmpeg..."
    apt update
    apt install -y ffmpeg
fi

# -------------------------------------------------
# GPU INFO
# -------------------------------------------------

echo "GPU Status:"
nvidia-smi || true

# -------------------------------------------------
# START JUPYTER
# -------------------------------------------------

echo "Starting Jupyter..."

jupyter lab \
--ip=0.0.0.0 \
--port=8888 \
--no-browser \
--allow-root \
--IdentityProvider.token='' &

sleep 3

# -------------------------------------------------
# START COMFYUI
# -------------------------------------------------

echo "Starting ComfyUI..."

cd $COMFY

exec $PYTHON main.py \
--listen 0.0.0.0 \
--port 8188
