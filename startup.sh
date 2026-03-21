#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "=========================================="
echo "CLEAN START (FINAL FIX - NO AIMDO)"
echo "=========================================="

# Fix DNS
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
cd $BASE
git clone https://github.com/comfyanonymous/ComfyUI.git

cd $COMFY

# 🚫 REMOVE AIMDO REFERENCES (KEY FIX)
echo "Removing problematic AIMDO references..."

find . -type f -name "*.py" -exec sed -i '/comfy_aimdo/d' {} +

# Install requirements
echo "Installing requirements..."

$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r requirements.txt

# Optional deps
$PYTHON -m pip install \
opencv-python \
scikit-image \
blake3

# Persistent folders
mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

# Start Jupyter
echo "Starting Jupyter..."
cd /workspace

$JUPYTER lab \
--notebook-dir=/workspace \
--ip=0.0.0.0 \
--port=8888 \
--no-browser \
--allow-root \
--ServerApp.allow_origin='*' \
--IdentityProvider.token='' &

sleep 3

# Start ComfyUI
echo "Starting ComfyUI..."
cd $COMFY

exec $PYTHON main.py --listen 0.0.0.0 --port 8188
