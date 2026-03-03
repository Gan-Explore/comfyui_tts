#!/bin/bash

echo "--------------------------------------"
echo "ComfyUI TTS Environment Booting"
echo "--------------------------------------"

COMFY_PATH="/workspace/runpod-slim/ComfyUI"
PYTHON_BIN="/opt/comfy_env/bin/python"

if [ -d "$COMFY_PATH" ]; then
    echo "Found ComfyUI volume."

    if [ -f "$COMFY_PATH/requirements.txt" ]; then
        echo "Installing ComfyUI requirements..."
        $PYTHON_BIN -m pip install --upgrade pip
        $PYTHON_BIN -m pip install -r $COMFY_PATH/requirements.txt
    else
        echo "requirements.txt not found. Skipping install."
    fi
else
    echo "ComfyUI path not found!"
    exit 1
fi

echo "Starting Jupyter..."
jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --IdentityProvider.token='' &

echo "Starting ComfyUI..."
cd $COMFY_PATH
exec $PYTHON_BIN main.py --listen 0.0.0.0 --port 8188
