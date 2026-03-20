#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "CLEAN START"
echo "========================================="

# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Wait for internet
for i in {1..20}; do
    ping -c 1 github.com && break
    sleep 2
done

# 🔥 ALWAYS CLEAN INSTALL
echo "Installing fresh ComfyUI..."
rm -rf $COMFY
cd $BASE
git clone https://github.com/comfyanonymous/ComfyUI.git
# Fix broken comfy_aimdo import safely
echo "Fixing comfy_aimdo import..."

sed -i 's/^import comfy_aimdo\.control/# disabled comfy_aimdo/' $COMFY/main.py

sed -i 's/^comfy_aimdo\.control\.init()/# disabled comfy_aimdo init/' $COMFY/main.py

# Create folders
mkdir -p $BASE/{models,input,output,custom_nodes}

# Link folders
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

# Start Jupyter
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
cd $COMFY
exec $PYTHON main.py --listen 0.0.0.0 --port 8188
