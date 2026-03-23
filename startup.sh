#!/bin/bash

# ❌ DO NOT exit on error (prevents restart loop)

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "CLEAN START (LOOP-PROOF + DEBUG MODE)"
echo "==========================================="

# 🔧 DNS FIX (safe)

echo "Fixing DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf || true
echo "nameserver 1.1.1.1" >> /etc/resolv.conf || true

echo "Current DNS:"
cat /etc/resolv.conf

# 🌐 Wait for network

echo "Waiting for network..."
for i in {1..20}; do
if ping -c 1 github.com > /dev/null 2>&1; then
echo "✅ Network OK"
break
fi
echo "⏳ Waiting..."
sleep 2
done

# 📦 Install / update ComfyUI (safe)

echo "Setting up ComfyUI..."

mkdir -p $BASE
cd $BASE

if [ ! -d "$COMFY" ]; then
echo "Cloning ComfyUI..."
git clone https://github.com/comfyanonymous/ComfyUI.git || echo "⚠️ Clone failed"
else
echo "ComfyUI already exists, skipping clone"
fi

cd $COMFY

# 📦 Install deps (non-fatal)

echo "Installing requirements..."
$PYTHON -m pip install --upgrade pip || true
$PYTHON -m pip install --no-cache-dir -r requirements.txt || echo "⚠️ requirements failed"

$PYTHON -m pip install opencv-python scikit-image blake3 || true

# 📁 Persistent dirs

mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# 🚀 Start Jupyter (fixed line breaks)

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

# 🚀 Start ComfyUI (NO exec, NO loop)

echo "Starting ComfyUI..."
cd $COMFY

$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "❌ ComfyUI exited. Container kept alive for debugging."
sleep infinity
