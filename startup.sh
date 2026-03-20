#!/bin/bash
set -e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"
CUSTOM="$BASE/custom_nodes"
CACHE="$BASE/model_cache"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "========================================="
echo "AI CREATION STACK BOOT (STABLE v5 DEBUG)"
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
# Create workspace
# -------------------------------------------------

mkdir -p $BASE/{models,input,output,user,custom_nodes}
mkdir -p $CACHE/{huggingface,torch,diffusers}

export HF_HOME=$CACHE/huggingface
export TRANSFORMERS_CACHE=$CACHE/huggingface

# -------------------------------------------------
# Install ComfyUI
# -------------------------------------------------

if [ ! -f "$COMFY/main.py" ]; then
    echo "Installing ComfyUI..."
    cd $BASE
    git clone https://github.com/comfyanonymous/ComfyUI.git || true
fi

# -------------------------------------------------
# Patch comfy_aimdo (safe)
# -------------------------------------------------

echo "Patching comfy_aimdo..."

MAIN_FILE="$COMFY/main.py"

if grep -q "comfy_aimdo.control.init()" "$MAIN_FILE"; then
    sed -i 's/import comfy_aimdo.control/try:\n    import comfy_aimdo.control\n    HAS_AIMDO = True\nexcept ImportError:\n    print("[WARN] comfy_aimdo not found")\n    HAS_AIMDO = False/' "$MAIN_FILE"

    sed -i 's/comfy_aimdo.control.init()/if HAS_AIMDO:\n    comfy_aimdo.control.init()/' "$MAIN_FILE"
fi

# -------------------------------------------------
# Link folders
# -------------------------------------------------

rm -rf $COMFY/{models,custom_nodes,input,output,user} || true

ln -s $BASE/models $COMFY/models
ln -s $BASE/custom_nodes $COMFY/custom_nodes
ln -s $BASE/input $COMFY/input
ln -s $BASE/output $COMFY/output
ln -s $BASE/user $COMFY/user

# -------------------------------------------------
# Debug info
# -------------------------------------------------

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
# 🚨 DEBUG MODE (IMPORTANT)
# -------------------------------------------------

echo "Starting ComfyUI (DEBUG MODE)..."

cd $COMFY

/opt/comfy_env/bin/python main.py \
--listen 0.0.0.0 \
--port 8188

echo "ComfyUI crashed. Keeping container alive..."
tail -f /dev/null
