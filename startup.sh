#!/bin/bash

set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CUSTOM="$BASE/custom_nodes"
CACHE="$BASE/model_cache"

PYTHON="/opt/comfy_env/bin/python"
PIP="/opt/comfy_env/bin/pip"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "AI CREATION STACK BOOT"
echo "========================================="

# -------------------------------------------------
# DNS FIX (RunPod cold start issue)
# -------------------------------------------------

echo "Fixing DNS..."

echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf


# -------------------------------------------------
# Wait for internet
# -------------------------------------------------

echo "Checking internet..."

for i in {1..60}
do
    if ping -c 1 github.com &> /dev/null; then
        echo "Internet OK"
        break
    fi
    echo "Waiting for network..."
    sleep 2
done


# -------------------------------------------------
# Create workspace
# -------------------------------------------------

mkdir -p $BASE
mkdir -p $CUSTOM
mkdir -p $BASE/models
mkdir -p $BASE/input
mkdir -p $BASE/output
mkdir -p $BASE/user

mkdir -p $CACHE/huggingface
mkdir -p $CACHE/torch
mkdir -p $CACHE/diffusers

export HF_HOME=$CACHE/huggingface
export TRANSFORMERS_CACHE=$CACHE/huggingface
export TORCH_HOME=$CACHE/torch
export XDG_CACHE_HOME=$CACHE


# -------------------------------------------------
# Install ComfyUI if missing
# -------------------------------------------------

if [ ! -f "$COMFY/main.py" ]; then

    echo "Installing ComfyUI..."

    cd $BASE

    rm -rf ComfyUI || true

    git clone https://github.com/comfyanonymous/ComfyUI.git

fi


# -------------------------------------------------
# Install dependencies (resilient pip)
# -------------------------------------------------

echo "Installing ComfyUI requirements..."

cd $COMFY

for i in {1..10}
do
    echo "PIP install attempt $i"

    $PIP install \
        --default-timeout=100 \
        --retries 20 \
        --no-cache-dir \
        -r requirements.txt && break

    echo "Network failure — retrying in 10 seconds..."
    sleep 10
done


# -------------------------------------------------
# Runtime dependencies (critical fixes)
# -------------------------------------------------

echo "Installing runtime dependencies..."

$PIP install --no-cache-dir \
gitpython \
"transformers<5"


# -------------------------------------------------
# Persistent folder linking
# -------------------------------------------------

echo "Linking persistent folders..."

rm -rf $COMFY/models || true
rm -rf $COMFY/custom_nodes || true
rm -rf $COMFY/input || true
rm -rf $COMFY/output || true
rm -rf $COMFY/user || true

ln -s $BASE/models $COMFY/models
ln -s $BASE/custom_nodes $COMFY/custom_nodes
ln -s $BASE/input $COMFY/input
ln -s $BASE/output $COMFY/output
ln -s $BASE/user $COMFY/user


# -------------------------------------------------
# Install ComfyUI Manager
# -------------------------------------------------

if [ ! -d "$CUSTOM/ComfyUI-Manager" ]; then

    echo "Installing ComfyUI Manager..."

    cd $CUSTOM
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git

fi


# -------------------------------------------------
# Install xformers if missing
# -------------------------------------------------

if ! $PYTHON -c "import xformers" &> /dev/null; then

    echo "Installing xformers..."

    $PIP install xformers \
    --extra-index-url https://download.pytorch.org/whl/cu124

fi


# -------------------------------------------------
# SELF HEALING PYTHON MODULE INSTALLER
# -------------------------------------------------

echo "Creating self-healing dependency system..."

mkdir -p $BASE/scripts

cat << 'EOF' > $BASE/scripts/self_heal.py
import subprocess
import sys
import re

print("Self-healing dependency scanner started...")

def install(pkg):
    print(f"Installing missing package: {pkg}")
    subprocess.call(["/opt/comfy_env/bin/pip","install",pkg])

while True:
    line=sys.stdin.readline()
    if not line:
        break

    match=re.search(r"No module named '([^']+)'",line)

    if match:
        pkg=match.group(1)
        install(pkg)
EOF


# -------------------------------------------------
# Start Jupyter
# -------------------------------------------------

echo "Starting Jupyter..."

cd /workspace

$JUPYTER lab \
--notebook-dir=/workspace \
--ServerApp.root_dir=/workspace \
--ServerApp.allow_origin='*' \
--ip=0.0.0.0 \
--port=8888 \
--no-browser \
--allow-root \
--IdentityProvider.token='' &

sleep 3


# -------------------------------------------------
# Start ComfyUI with self-healing
# -------------------------------------------------

echo "Starting ComfyUI..."

cd $COMFY

$PYTHON main.py \
--listen 0.0.0.0 \
--port 8188 2>&1 | tee /tmp/comfy.log | $PYTHON $BASE/scripts/self_heal.py
