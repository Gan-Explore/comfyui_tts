#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
PYTHON="/opt/comfy_env/bin/python"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# Setup directories
mkdir -p $BASE/{models,input,output,custom_nodes}

# Symlink SoulX-Singer if needed
if [ -d "/workspace/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer" ]; then
  echo "SoulX-Singer node found"
fi

# Set environment variables
export SOULX_SINGER_ROOT=/workspace/ComfyUI/pretrained_models
export PYTHONPATH=/workspace/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# Start Jupyter (optional)
if command -v jupyter &> /dev/null; then
  echo "Starting Jupyter on port 8888..."
  jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root \
    --ServerApp.token='' --ServerApp.allow_origin='*' &
fi

# Start ComfyUI (the base image handles this typically)
echo "Starting ComfyUI on port 8188..."
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188

sleep infinity
