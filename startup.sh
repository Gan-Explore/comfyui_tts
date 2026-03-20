#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "CLEAN START (ULTIMATE FINAL)"
echo "========================================="

# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Wait for internet
for i in {1..20}; do
    ping -c 1 github.com && break
    sleep 2
done

# Clean install ComfyUI
echo "Installing fresh ComfyUI..."
rm -rf $COMFY
cd $BASE
git clone https://github.com/comfyanonymous/ComfyUI.git

cd $COMFY

# Install official requirements
echo "Installing ComfyUI requirements..."

$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install -r requirements.txt

# Optional extras
$PYTHON -m pip install \
opencv-python \
scikit-image \
blake3

# 🔥 COMPLETE comfy_aimdo stub (FINAL FIX)
echo "Creating full comfy_aimdo stub..."

mkdir -p /workspace/fake_modules/comfy_aimdo

# __init__
cat <<EOF > /workspace/fake_modules/comfy_aimdo/__init__.py
from .control import init
EOF

# control.py
cat <<EOF > /workspace/fake_modules/comfy_aimdo/control.py
def init():
    print("[INFO] comfy_aimdo stub loaded — doing nothing")
EOF

# model_vbar.py (fixes your current crash)
cat <<EOF > /workspace/fake_modules/comfy_aimdo/model_vbar.py
class ModelVBar:
    def __init__(self, *args, **kwargs):
        pass
EOF

export PYTHONPATH="/workspace/fake_modules:$PYTHONPATH"

# Create persistent folders
mkdir -p $BASE/{models,input,output,custom_nodes}

# Link persistent storage
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
