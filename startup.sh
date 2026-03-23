#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "CLEAN START (FIXED STABLE VERSION)"
echo "==========================================="

# Wait a bit for network

sleep 5

# Fresh install

echo "Installing ComfyUI..."
rm -rf $COMFY
mkdir -p $BASE
cd $BASE

git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Install requirements

echo "Installing requirements..."
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install --no-cache-dir -r requirements.txt

# Optional deps

$PYTHON -m pip install opencv-python scikit-image blake3 || true

# Persistent folders

mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

# ✅ Correct custom_nodes linking

rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# Start Jupyter

echo "Starting Jupyter..."
cd /workspace

$JUPYTER lab 
--notebook-dir=/workspace 
--ip=0.0.0.0 
--port=8888 
--no-browser 
--allow-root 
--ServerApp.allow_origin='*' 
--IdentityProvider.token='' &

sleep 3

# Start ComfyUI

echo "Starting ComfyUI..."
cd $COMFY

exec $PYTHON main.py --listen 0.0.0.0 --port 8188
