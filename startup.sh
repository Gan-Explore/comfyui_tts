#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "CLEAN START (LATEST — STABLE, NO PATCH)"
echo "==========================================="

# DNS fix

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Wait for internet

for i in {1..20}; do
ping -c 1 github.com && break
sleep 2
done

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
$PYTHON -m pip install -r requirements.txt

# Optional deps

$PYTHON -m pip install opencv-python scikit-image blake3

# Optional fallback (safe if not needed)

$PYTHON -m pip install comfy-aimdo || echo "comfy_aimdo not needed"

# Persistent folders

mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

# ✅ FIX custom_nodes (avoid recursive symlink issue)

rm -rf $COMFY/custom_nodes
mkdir -p $COMFY/custom_nodes
rm -rf $COMFY/custom_nodes/custom_nodes 2>/dev/null || true
ln -sfn $BASE/custom_nodes/* $COMFY/custom_nodes/ 2>/dev/null || true

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
