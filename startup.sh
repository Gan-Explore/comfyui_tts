#!/bin/bash

set +e

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# Start Jupyter Lab on port 8888
echo "Starting Jupyter Lab on port 8888..."
jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.allow_origin='*' \
  --ServerApp.token='' &

sleep 3

# Set environment variables for SoulX-Singer
export SOULX_SINGER_ROOT=/workspace/ComfyUI/pretrained_models
export PYTHONPATH=/workspace/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# The base image automatically starts ComfyUI on port 8188
# We don't need to start it manually - it's handled by the base image's entrypoint

echo "Ready! ComfyUI will start automatically on port 8188"
echo "Jupyter Lab available on port 8888"

# The base image's entrypoint will now take over
# This script is sourced by the base image's startup process
