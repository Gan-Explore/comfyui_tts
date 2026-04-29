#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# Check if ComfyUI exists at the correct path
if [ ! -d "$COMFY" ]; then
    echo "ERROR: ComfyUI not found at $COMFY"
    echo "Available directories:"
    ls -la /workspace/
# Create directory structure
    echo "Creating directory structure and installing ComfyUI...."
    mkdir -p /workspace/runpod-slim/ComfyUI

# Clone ComfyUI to the correct path
    git clone https://github.com/comfyanonymous/ComfyUI.git /workspace/runpod-slim/ComfyUI

# Install ComfyUI requirements
    pip install --no-cache-dir -r /workspace/runpod-slim/ComfyUI/requirements.txt || true
fi

echo "ComfyUI found at $COMFY"

# Setup symlinks (create directories if they don't exist)
# mkdir -p $BASE/{models,input,output,custom_nodes}
# mkdir -p $COMFY

# ln -sfn $BASE/models $COMFY/models
# ln -sfn $BASE/input $COMFY/input
# ln -sfn $BASE/output $COMFY/output
# ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

echo "Directory structure:"
ls -la $COMFY/

# Start Jupyter
echo "Starting Jupyter Lab on port 8888..."
$PYTHON -m jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.allow_origin='*' \
  --ServerApp.token='' &

sleep 3

# Set environment variables
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# Start ComfyUI
echo "Starting ComfyUI on port 8188..."
cd $COMFY

# Verify main.py exists
if [ ! -f "main.py" ]; then
    echo "ERROR: main.py not found in $COMFY"
    echo "Contents of $COMFY:"
    ls -la $COMFY/
    exit 1
fi

$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
