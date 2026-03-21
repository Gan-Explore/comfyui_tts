#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "=========================================="
echo "CLEAN START (ULTIMATE FINAL - IMPORT SAFE)"
echo "=========================================="

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

# 🔥 IMPORT-SAFE comfy_aimdo FIX (FINAL)
echo "Creating import-safe comfy_aimdo stub..."

mkdir -p /workspace/fake_modules/comfy_aimdo

cat <<EOF > /workspace/fake_modules/comfy_aimdo/__init__.py
import sys
import types

class Dummy(types.ModuleType):
    def __getattr__(self, name):
        fullname = f"{self.__name__}.{name}"
        if fullname in sys.modules:
            return sys.modules[fullname]
        mod = Dummy(fullname)
        sys.modules[fullname] = mod
        return mod

    def __call__(self, *args, **kwargs):
        return None

    def __iter__(self):
        return iter([])

    def __bool__(self):
        return False

    def __len__(self):
        return 0

# Base module
dummy = Dummy("comfy_aimdo")

# 🔥 CRITICAL: pre-register required submodules
for sub in ["control", "model_vbar", "host_buffer"]:
    fullname = f"comfy_aimdo.{sub}"
    mod = Dummy(fullname)
    sys.modules[fullname] = mod

sys.modules["comfy_aimdo"] = dummy
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
