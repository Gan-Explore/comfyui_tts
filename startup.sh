#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# DNS fix for better connectivity
echo "nameserver 8.8.8.8" > /etc/resolv.conf || true
echo "nameserver 1.1.1.1" >> /etc/resolv.conf || true

# Wait for network
for i in {1..20}; do
  ping -c 1 github.com > /dev/null 2>&1 && break
  sleep 2
done

# Setup directories
mkdir -p $BASE
cd $BASE

# Clone ComfyUI if not exists
if [ ! -d "$COMFY" ]; then
  echo "Cloning ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI.git
else
  echo "ComfyUI already exists"
fi

cd $COMFY

# ============================================
# CRITICAL: Patch requirements.txt to remove comfy-kitchen
# ============================================
echo "Patching ComfyUI requirements.txt to remove comfy-kitchen..."
sed -i '/comfy-kitchen/d' requirements.txt

# ============================================
# Force pinned versions FIRST
# ============================================
echo "Installing pinned versions..."

$PYTHON -m pip uninstall numpy comfy-kitchen -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps
$PYTHON -m pip install comfy-kitchen==0.2.3 --force-reinstall --no-deps

# ============================================
# Install ComfyUI requirements (now without comfy-kitchen)
# ============================================
echo "Installing ComfyUI requirements..."
$PYTHON -m pip install --no-cache-dir -r requirements.txt || true

# ============================================
# Re-pin after requirements
# ============================================
$PYTHON -m pip uninstall numpy comfy-kitchen -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps
$PYTHON -m pip install comfy-kitchen==0.2.3 --force-reinstall --no-deps

# ============================================
# Install compatible opencv and scikit-image
# ============================================
$PYTHON -m pip install opencv-python==4.8.1.78 scikit-image==0.21.0 --force-reinstall --no-deps || true

# ============================================
# Install Jupyter and dependencies manually
# ============================================
echo "Installing Jupyter..."
$PYTHON -m pip install jupyter jupyterlab ipykernel notebook --no-deps || true
$PYTHON -m pip install traitlets tornado jupyter-core jupyter-server --no-deps || true

# ============================================
# Setup directory symlinks
# ============================================
mkdir -p $BASE/{models,input,output,custom_nodes}
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# Start Jupyter Lab (if available)
# ============================================
echo "Starting Jupyter Lab on port 8888..."
cd /workspace
if $PYTHON -c "import jupyter" 2>/dev/null; then
  $PYTHON -m jupyter lab \
    --notebook-dir=/workspace \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --ServerApp.allow_origin='*' \
    --IdentityProvider.token='' &
else
  echo "Jupyter not available, skipping..."
fi

sleep 3

# ============================================
# Set environment variables
# ============================================
export SOULX_SINGER_ROOT=/workspace/runpod-slim/ComfyUI/pretrained_models
export PYTHONPATH=/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# ============================================
# Final verification
# ============================================
echo "Verifying runtime environment..."
$PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
$PYTHON -c "import comfy_kitchen; print(f'comfy-kitchen: {comfy_kitchen.__version__}')"

# ============================================
# Start ComfyUI
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY
$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
