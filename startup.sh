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
# Wait for internet
# -------------------------------------------------

echo "Checking internet connectivity..."

for i in {1..20}
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

mkdir -p $BASE
mkdir -p $CUSTOM
mkdir -p $BASE/models
mkdir -p $BASE/input
mkdir -p $BASE/output
mkdir -p $BASE/user

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
# Install ComfyUI dependencies
# -------------------------------------------------

echo "Installing ComfyUI dependencies..."

cd $COMFY

for i in {1..5}
do
    $PYTHON -m pip install --no-cache-dir -r requirements.txt && break
    echo "pip failed — retrying..."
    sleep 5
done

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
# Install xformers
# -------------------------------------------------

if ! $PYTHON -c "import xformers" 2>/dev/null; then
    echo "Installing xformers..."
    $PYTHON -m pip install xformers \
    --extra-index-url https://download.pytorch.org/whl/cu124
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
