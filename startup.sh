#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "CLEAN START (STABLE MODE)"
echo "========================================="

# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Wait for internet
for i in {1..20}; do
    ping -c 1 github.com && break
    sleep 2
done

# Clean install
echo "Installing fresh ComfyUI..."
rm -rf $COMFY
cd $BASE
git clone https://github.com/comfyanonymous/ComfyUI.git

# 🔥 KEY FIX: create fake comfy_aimdo module
echo "Creating safe comfy_aimdo stub..."

mkdir -p /workspace/fake_modules/comfy_aimdo

cat <<EOF > /workspace/fake_modules/comfy_aimdo/__init__.py
from .control import init
EOF

cat <<EOF > /workspace/fake_modules/comfy_aimdo/control.py
def init():
    print("[INFO] comfy_aimdo stub loaded — doing nothing")
EOF

# Inject into PYTHONPATH
export PYTHONPATH="/workspace/fake_modules:$PYTHONPATH"

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
