#!/bin/bash

echo "---------------------------------------"
echo "ComfyUI + TTS Environment Booting"
echo "---------------------------------------"

COMFY_PATH="/workspace/runpod-slim/ComfyUI"
PYTHON_BIN="/opt/comfy_env/bin/python"

echo "Python:"
$PYTHON_BIN --version

echo "Checking ComfyUI path..."

if [ ! -d "$COMFY_PATH" ]; then
    echo "ERROR: ComfyUI directory not found!"
    echo "Expected: $COMFY_PATH"
    exit 1
fi

cd $COMFY_PATH

echo "---------------------------------------"
echo "Checking for broken AIMDO import"
echo "---------------------------------------"

if grep -q "comfy_aimdo" main.py; then
    echo "Removing obsolete comfy_aimdo import..."
    sed -i '/comfy_aimdo/d' main.py
fi

echo "---------------------------------------"
echo "Checking dependencies"
echo "---------------------------------------"

if ! $PYTHON_BIN -c "import aiohttp" 2>/dev/null; then
    echo "Core dependencies missing. Installing requirements..."
    $PYTHON_BIN -m pip install --upgrade pip
    $PYTHON_BIN -m pip install -r requirements.txt
else
    echo "Dependencies already installed."
fi

echo "---------------------------------------"
echo "Starting Jupyter Lab"
echo "---------------------------------------"

jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --IdentityProvider.token='' &

sleep 3

echo "---------------------------------------"
echo "Starting ComfyUI"
echo "---------------------------------------"

exec $PYTHON_BIN main.py \
    --listen 0.0.0.0 \
    --port 8188
