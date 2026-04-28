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

# Clone ComfyUI if not exists
if [ ! -d "$COMFY" ]; then
  echo "Cloning ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI.git
else
  echo "ComfyUI already exists"
fi

cd $COMFY

# ============================================
# PATCH 1: Remove comfy-kitchen dependency
# ============================================
echo "Patching ComfyUI to bypass comfy-kitchen..."
sed -i '/comfy-kitchen/d' requirements.txt

if [ -f "comfy/memory_management.py" ]; then
  sed -i 's/from comfy.quant_ops import QuantizedTensor/# from comfy.quant_ops import QuantizedTensor/g' comfy/memory_management.py
fi

cat > comfy/quant_ops.py << 'EOF'
# Dummy quant_ops.py - replaces comfy-kitchen dependency
class QuantizedTensor:
    """Dummy QuantizedTensor class to replace comfy-kitchen"""
    pass

ck = None
EOF

# ============================================
# PATCH 2: Fix NumPy compatibility
# ============================================
echo "Patching ComfyUI for NumPy 1.x compatibility..."

if [ -f "comfy/utils.py" ]; then
  sed -i 's/from numpy.dtypes import Float64DType/from numpy import float64 as Float64DType/g' comfy/utils.py
fi

# ============================================
# PATCH 3: Fix torch.serialization compatibility for PyTorch 2.2.0
# ============================================
echo "Patching ComfyUI for PyTorch 2.2.0 compatibility..."

# Create a wrapper to add add_safe_globals if it doesn't exist
cat > comfy/safe_globals_patch.py << 'EOF'
# Patch for torch.serialization.add_safe_globals in PyTorch 2.2.0
import torch

if not hasattr(torch.serialization, 'add_safe_globals'):
    def add_safe_globals(globals_list):
        # Do nothing - this is a no-op for older PyTorch versions
        pass
    torch.serialization.add_safe_globals = add_safe_globals
    print("Patched: added torch.serialization.add_safe_globals for PyTorch 2.2.0")
EOF

# Import the patch at the beginning of main.py
sed -i '1iimport comfy.safe_globals_patch' main.py

# Also patch utils.py if needed
if [ -f "comfy/utils.py" ]; then
  sed -i '1iimport comfy.safe_globals_patch' comfy/utils.py
fi

# ============================================
# Install NumPy 1.24.4
# ============================================
echo "Installing NumPy 1.24.4..."
$PYTHON -m pip uninstall numpy comfy-kitchen -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# Install ComfyUI requirements
# ============================================
echo "Installing ComfyUI requirements..."
$PYTHON -m pip install --no-cache-dir -r requirements.txt || true

# ============================================
# Reinstall NumPy (in case it got upgraded)
# ============================================
$PYTHON -m pip uninstall numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# Install other dependencies
# ============================================
echo "Installing additional dependencies..."
$PYTHON -m pip install opencv-python==4.8.1.78 scikit-image==0.21.0 --force-reinstall --no-deps || true

# Install Jupyter
$PYTHON -m pip install jupyter jupyterlab ipykernel notebook || true

# ============================================
# Setup symlinks
# ============================================
mkdir -p $BASE/{models,input,output,custom_nodes}
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
rm -rf $COMFY/custom_nodes
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# Start Jupyter
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
# Environment variables
# ============================================
export SOULX_SINGER_ROOT=/workspace/runpod-slim/ComfyUI/pretrained_models
export PYTHONPATH=/workspace/runpod-slim/ComfyUI/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# ============================================
# Final verification
# ============================================
echo "Verifying environment..."
$PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
$PYTHON -c "from comfy.utils import *; print('ComfyUI utils imported successfully')"

# ============================================
# Start ComfyUI
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY
$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
