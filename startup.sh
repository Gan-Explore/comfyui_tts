#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "CLEAN START (STABLE + QWEN READY)"
echo "==========================================="

# 🌐 DNS FIX

echo "Fixing DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf || true
echo "nameserver 1.1.1.1" >> /etc/resolv.conf || true

echo "Waiting for network..."
for i in {1..20}; do
ping -c 1 github.com > /dev/null 2>&1 && break
sleep 2
done

# 📦 Setup ComfyUI (NO REINSTALL LOOP)

mkdir -p $BASE
cd $BASE

if [ ! -d "$COMFY" ]; then
echo "Cloning ComfyUI..."
git clone https://github.com/comfyanonymous/ComfyUI.git
else
echo "ComfyUI already exists, skipping clone"
fi

cd $COMFY

# 📦 Install requirements (safe)

echo "Installing ComfyUI requirements..."
$PYTHON -m pip install --upgrade pip
$PYTHON -m pip install --no-cache-dir -r requirements.txt || true
$PYTHON -m pip install opencv-python scikit-image blake3 || true

# 📁 Persistent dirs

mkdir -p $BASE/{models,input,output,custom_nodes}

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output

rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# 🔥 Install Qwen-TTS (CRITICAL FIX)

echo "Setting up Qwen-TTS..."

cd $BASE/custom_nodes

if [ ! -d "ComfyUI-Qwen-TTS" ]; then
echo "Cloning Qwen-TTS nodes..."
git clone https://github.com/flybirdxx/ComfyUI-Qwen-TTS.git
fi

cd ComfyUI-Qwen-TTS

echo "Installing Qwen-TTS requirements..."
$PYTHON -m pip install -r requirements.txt || true

echo "Installing core Qwen-TTS package..."
$PYTHON -m pip install qwen-tts || true

# 🚀 Start Jupyter

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

# 🚀 Start ComfyUI (no loop)

echo "Starting ComfyUI..."
cd $COMFY

$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "❌ ComfyUI exited. Debug mode active."
sleep infinity
