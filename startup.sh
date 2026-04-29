#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="/workspace/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# Setup symlinks
mkdir -p $BASE/{models,input,output,custom_nodes}
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

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
$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
