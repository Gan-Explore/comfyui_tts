#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CACHE="$BASE/model_cache"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "AI STACK BOOT (FINAL STABLE)"
echo "========================================="

# -------------------------------------------------
# Fix DNS
# -------------------------------------------------

echo "Fixing DNS..."
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# -------------------------------------------------
# Wait for internet
# -------------------------------------------------

echo "Checking internet..."
for i in {1..30}; do
    if ping -c 1 github.com &> /dev/null; then
        echo "Internet OK"
        break
    fi
    sleep 2
done

# -------------------------------------------------
# CLEAN INSTALL (CRITICAL FIX)
# -------------------------------------------------

echo "Resetting ComfyUI..."

rm -rf $COMFY

cd $BASE
git clone https://github.com/comfyanonymous/ComfyUI.git

# -------------------------------------------------
# Create folders
# -------------------------------------------------

mkdir -p $BASE/{models,input,output,user,custom_nodes}
mkdir -p $CACHE/{huggingface,torch,diffusers}

export HF_HOME=$CACHE/huggingface
export TRANSFORMERS_CACHE=$CACHE/huggingface

# -------------------------------------------------
# Link folders
# -------------------------------------------------

echo "Linking storage..."

ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
ln -sfn $BASE/user $COMFY/user

# -------------------------------------------------
# Debug
# -------------------------------------------------

echo "Python:"
which python

python -c "import transformers; print('Transformers:', transformers.__version__)"

# -------------------------------------------------
# Start Jupyter
# -------------------------------------------------

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

# -------------------------------------------------
# Start ComfyUI (ONLY ONCE)
# -------------------------------------------------

echo "Starting ComfyUI..."

cd $COMFY

exec $PYTHON main.py \
--listen 0.0.0.0 \
--port 8188
