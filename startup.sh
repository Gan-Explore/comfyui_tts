#!/bin/bash

set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CUSTOM="$BASE/custom_nodes"
CACHE="$BASE/model_cache"

PYTHON="/opt/comfy_env/bin/python"
PIP="/opt/comfy_env/bin/pip"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "AI CREATION STACK BOOT"
echo "========================================="

# -------------------------------------------------
# Wait for internet
# -------------------------------------------------

echo "Checking internet..."

for i in {1..30}
do
    if ping -c 1 github.com &> /dev/null; then
        echo "Internet OK"
        break
    fi
    echo "Waiting for network..."
    sleep 2
done

# -------------------------------------------------
# Create workspace
# -------------------------------------------------

mkdir -p $BASE
mkdir -p $CUSTOM
mkdir -p $BASE/models
mkdir -p $BASE/input
mkdir -p $BASE/output
mkdir -p $BASE/user

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

    rm -rf ComfyUI || true

    git clone https://github.com/comfyanonymous/ComfyUI.git

fi

# -------------------------------------------------
# Install dependencies
# -------------------------------------------------

echo "Installing ComfyUI requirements..."

cd $COMFY

for i in {1..5}
do
    $PIP install --no-cache-dir -r requirements.txt && break
    echo "Retry pip install..."
    sleep 5
done

# -------------------------------------------------
# Persistent folder linking
# -------------------------------------------------

echo "Linking persistent folders..."

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

if ! $PYTHON -c "import xformers" &> /dev/null; then

    echo "Installing xformers..."

    $PIP install xformers \
    --extra-index-url https://download.pytorch.org/whl/cu124

fi

# -------------------------------------------------
# Start Jupyter
# -------------------------------------------------

echo "Starting Jupyter..."

$JUPYTER lab \
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
