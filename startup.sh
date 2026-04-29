#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"
JUPYTER="/opt/comfy_env/bin/jupyter"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# DNS fix
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

# ============================================
# STEP 1: Clone specific working version of ComfyUI
# ============================================
if [ ! -d "$COMFY" ]; then
  echo "Cloning ComfyUI (stable version from Dec 2024)..."
  git clone https://github.com/comfyanonymous/ComfyUI.git
  cd $COMFY
  # Checkout a stable commit that works with PyTorch 2.2.0
  git checkout 172fd62
  echo "Checked out stable commit 172fd62"
else
  echo "ComfyUI already exists"
  cd $COMFY
  # Ensure we're on the stable version
  git checkout 172fd62 2>/dev/null || true
fi

# ============================================
# STEP 2: Remove comfy-kitchen from requirements
# ============================================
echo "Removing comfy-kitchen from requirements..."
sed -i '/comfy-kitchen/d' requirements.txt 2>/dev/null || true

# ============================================
# STEP 3: Install NumPy 1.24.4
# ============================================
echo "Installing NumPy 1.24.4..."
$PYTHON -m pip uninstall numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 4: Install ComfyUI requirements
# ============================================
echo "Installing ComfyUI requirements..."
$PYTHON -m pip install --no-cache-dir -r requirements.txt || true

# ============================================
# STEP 5: Re-pin NumPy
# ============================================
$PYTHON -m pip uninstall numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 6: Install other dependencies
# ============================================
echo "Installing additional dependencies..."
$PYTHON -m pip install opencv-python==4.8.1.78 scikit-image==0.21.0 --force-reinstall --no-deps || true
$PYTHON -m pip install jupyter jupyterlab ipykernel notebook || true

# ============================================
# STEP 7: Setup symlinks
# ============================================
mkdir -p $BASE/{models,input,output,custom_nodes}
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 8: Start Jupyter
# ============================================
echo "Starting Jupyter Lab on port 8888..."
cd /workspace
$PYTHON -m jupyter lab \
  --notebook-dir=/workspace \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.allow_origin='*' \
  --IdentityProvider.token='' &

sleep 3

# ============================================
# STEP 9: Environment variables
# ============================================
export SOULX_SINGER_ROOT=/workspace/runpod-slim/ComfyUI/pretrained_models
export PYTHONPATH=/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# ============================================
# STEP 10: Final verification
# ============================================
echo "Verifying environment..."
$PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"

# ============================================
# STEP 11: Start ComfyUI
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY
$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
