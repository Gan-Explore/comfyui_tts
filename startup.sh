#!/bin/bash

set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CUSTOM="$BASE/custom_nodes"
CACHE="$BASE/model_cache"
PYTHON="/opt/comfy_env/bin/python"

echo "========================================"
echo "AI CREATION STACK BOOT"
echo "========================================"

# -------------------------------------------------
# Wait for internet (RunPod DNS fix)
# -------------------------------------------------

echo "Checking internet connectivity..."

for i in {1..10}
do
    if ping -c 1 github.com &> /dev/null; then
        echo "Internet available."
        break
    fi
    echo "Waiting for network..."
    sleep 3
done

# -------------------------------------------------
# Create base workspace
# -------------------------------------------------

mkdir -p $BASE/models
mkdir -p $BASE/custom_nodes
mkdir -p $BASE/input
mkdir -p $BASE/output
mkdir -p $BASE/user

# -------------------------------------------------
# GPU optimization
# -------------------------------------------------

export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:128
export CUDA_DEVICE_MAX_CONNECTIONS=1
export CUDA_LAUNCH_BLOCKING=0
export TORCH_CUDNN_V8_API_ENABLED=1

# -------------------------------------------------
# Cache folders
# -------------------------------------------------

mkdir -p $CACHE/huggingface
mkdir -p $CACHE/torch
mkdir -p $CACHE/diffusers

export HF_HOME=$CACHE/huggingface
export TRANSFORMERS_CACHE=$CACHE/huggingface
export TORCH_HOME=$CACHE/torch
export XDG_CACHE_HOME=$CACHE

# -------------------------------------------------
# Install ComfyUI if missing
# -------------------------------------------------

if [ ! -f "$COMFY/main.py" ]; then

    echo "Installing ComfyUI..."

    cd $BASE
    git clone https://github.com/comfyanonymous/ComfyUI.git

fi

# -------------------------------------------------
# Install dependencies (SELF HEALING)
# -------------------------------------------------

echo "Installing ComfyUI dependencies..."

cd $COMFY

$PYTHON -m pip install --upgrade pip setuptools wheel

for i in {1..5}
do
    $PYTHON -m pip install --no-cache-dir -r requirements.txt && break
    echo "pip failed — retrying..."
    sleep 5
done

# -------------------------------------------------
# Fix missing modules (extra safety)
# -------------------------------------------------

$PYTHON -m pip install \
aiohttp \
alembic \
sqlalchemy \
--no-cache-dir || true

# -------------------------------------------------
# Link persistent folders
# -------------------------------------------------

rm -rf $COMFY/models || true
rm -rf $COMFY/custom_nodes || true
rm -rf $COMFY/input || true
rm -rf $COMFY/output || true
rm -rf $COMFY/user || true

ln -s $BASE/models $COMFY/models
ln -s $BASE/custom_nodes $COMFY/custom_nodes
ln -s $BASE/input $COMFY/input
ln -s $BASE/output $COMFY/output
ln -s $BASE/user $COMFY/user

# -------------------------------------------------
# Install ComfyUI Manager
# -------------------------------------------------

if [ ! -d "$CUSTOM/ComfyUI-Manager" ]; then
    echo "Installing ComfyUI Manager..."

    cd $CUSTOM
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
fi

# -------------------------------------------------
# GPU acceleration
# -------------------------------------------------

if ! $PYTHON -c "import xformers" 2>/dev/null; then

    echo "Installing xformers..."

    $PYTHON -m pip install xformers \
    --extra-index-url https://download.pytorch.org/whl/cu124
fi

# -------------------------------------------------
# Install AIMDO if missing
# -------------------------------------------------

if ! $PYTHON -c "import comfy_aimdo" 2>/dev/null; then
    echo "Installing comfy_aimdo..."
    $PYTHON -m pip install comfy-aimdo || true
fi

# -------------------------------------------------
# Start Jupyter
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
# Start ComfyUI
# -------------------------------------------------

echo "Starting ComfyUI..."

cd $COMFY

exec $PYTHON main.py \
--listen 0.0.0.0 \
--port 8188
