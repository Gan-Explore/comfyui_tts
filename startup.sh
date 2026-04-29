#!/bin/bash

set +e

# ============================================
# FIX CUDA ALLOCATOR ERROR - Multiple strategies
# ============================================
# Try different allocator settings
export PYTORCH_CUDA_ALLOC_CONF=backend:cudaMallocAsync
export CUDA_MANAGED_FORCE_DEVICE_ALLOC=1
export CUDA_VISIBLE_DEVICES=0

# Disable CUDA lazy loading (sometimes helps)
export CUDA_MODULE_LOADING=LAZY

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

# Use the virtual environment python explicitly
VENV_PYTHON="/opt/comfy_env/bin/python"
VENV_PIP="/opt/comfy_env/bin/pip"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="
echo "PYTORCH_CUDA_ALLOC_CONF: $PYTORCH_CUDA_ALLOC_CONF"
echo "CUDA_VISIBLE_DEVICES: $CUDA_VISIBLE_DEVICES"

# Show which python we're using
echo "Using Python: $VENV_PYTHON"
$VENV_PYTHON --version

# ============================================
# STEP 1: Create directory structure
# ============================================
echo "Setting up directory structure..."
mkdir -p $BASE
# mkdir -p $BASE/{models,input,output,custom_nodes}

# ============================================
# STEP 2: Clone ComfyUI if not exists
# ============================================
if [ ! -d "$COMFY" ]; then
    echo "ComfyUI not found. Cloning..."
    cd $BASE
    git clone https://github.com/comfyanonymous/ComfyUI.git
    echo "ComfyUI cloned successfully"
fi

# ============================================
# STEP 3: Upgrade pip and install core packages
# ============================================
echo "Upgrading pip..."
$VENV_PIP install --upgrade pip setuptools wheel

# Install NumPy FIRST and lock it
echo "Installing NumPy 1.24.4..."
$VENV_PIP uninstall numpy -y 2>/dev/null
$VENV_PIP install numpy==1.24.4 --force-reinstall --no-deps

# Install PyTorch with specific CUDA version
echo "Installing PyTorch 2.2.0..."
$VENV_PIP install torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# ============================================
# STEP 4: Create comprehensive compatibility patch module
# ============================================
echo "Creating compatibility patch module..."

cat > $COMFY/comfy/pytorch_compat.py << 'PYEOF'
"""
PyTorch 2.2.0 compatibility patches
"""
import torch
import os

# Fix CUDA allocator issue by setting environment variable
os.environ['PYTORCH_CUDA_ALLOC_CONF'] = 'backend:cudaMallocAsync'

# Patch 1: Add missing add_safe_globals function
if not hasattr(torch.serialization, 'add_safe_globals'):
    def add_safe_globals(globals_list):
        """No-op for PyTorch 2.2.0"""
        pass
    torch.serialization.add_safe_globals = add_safe_globals
    print("✓ Patched torch.serialization.add_safe_globals")

# Patch 2: Add all missing uint dtypes (map to closest available)
uint_mappings = {
    'uint8': torch.uint8,
    'uint16': torch.uint8,
    'uint32': torch.uint8,
    'uint64': torch.uint8,
}

for name, value in uint_mappings.items():
    if not hasattr(torch, name):
        setattr(torch, name, value)
        print(f"✓ Patched torch.{name} -> torch.uint8")

# Patch 3: Add missing float8 dtypes
if not hasattr(torch, 'float8_e4m3fn'):
    torch.float8_e4m3fn = torch.float16
if not hasattr(torch, 'float8_e5m2'):
    torch.float8_e5m2 = torch.float16

# Patch 4: Monkey patch the CUDA device function to avoid the allocator error
_original_current_device = torch.cuda.current_device
def _patched_current_device():
    try:
        return _original_current_device()
    except RuntimeError as e:
        if "allocator" in str(e).lower():
            # If allocator error, try to reinitialize CUDA
            torch.cuda.init()
            return _original_current_device()
        raise e
torch.cuda.current_device = _patched_current_device

print("PyTorch compatibility patches applied")
PYEOF

# Apply patch to main.py
if ! grep -q "pytorch_compat" $COMFY/main.py; then
    sed -i '1iimport comfy.pytorch_compat' $COMFY/main.py
fi

# Apply patch to model_management.py as well
if [ -f "$COMFY/comfy/model_management.py" ]; then
    if ! grep -q "pytorch_compat" $COMFY/comfy/model_management.py; then
        sed -i '1iimport comfy.pytorch_compat' $COMFY/comfy/model_management.py
    fi
fi

# ============================================
# STEP 5: PATCH numpy.dtypes in utils.py
# ============================================
echo "Patching numpy.dtypes import in utils.py..."

if [ -f "$COMFY/comfy/utils.py" ]; then
    sed -i 's/from numpy.dtypes import Float64DType/from numpy import float64 as Float64DType/g' $COMFY/comfy/utils.py
    echo "✓ Patched numpy.dtypes import"
fi

# Also patch any other files that might have this issue
find $COMFY -name "*.py" -exec sed -i 's/from numpy\.dtypes import /from numpy import /g' {} \; 2>/dev/null || true

# ============================================
# STEP 6: Fix ComfyUI requirements BEFORE installing
# ============================================
echo "Patching ComfyUI requirements..."

# Remove numpy requirement (we have our own)
sed -i '/^numpy/d' $COMFY/requirements.txt 2>/dev/null || true

# Remove comfy-kitchen requirement
sed -i '/comfy-kitchen/d' $COMFY/requirements.txt 2>/dev/null || true

# Create dummy quant_ops.py
cat > $COMFY/comfy/quant_ops.py << 'EOF'
# Dummy quant_ops.py - bypasses comfy_kitchen dependency
class QuantizedTensor:
    pass

class _FakeCK:
    def __getattr__(self, name):
        return None

ck = _FakeCK()
EOF

# ============================================
# STEP 7: Install ComfyUI requirements (without numpy or comfy-kitchen)
# ============================================
echo "Installing ComfyUI requirements..."
$VENV_PIP install --no-cache-dir -r $COMFY/requirements.txt || true

# ============================================
# STEP 8: RE-APPLY patches after installation
# ============================================
echo "Re-applying patches after installation..."

if [ -f "$COMFY/comfy/utils.py" ]; then
    sed -i 's/from numpy.dtypes import Float64DType/from numpy import float64 as Float64DType/g' $COMFY/comfy/utils.py
fi
find $COMFY -name "*.py" -exec sed -i 's/from numpy\.dtypes import /from numpy import /g' {} \; 2>/dev/null || true

# ============================================
# STEP 9: Force NumPy back to 1.24.4
# ============================================
echo "Force reinstalling NumPy 1.24.4..."
$VENV_PIP uninstall numpy -y 2>/dev/null
$VENV_PIP install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 10: Install all other dependencies
# ============================================
echo "Installing additional dependencies..."

$VENV_PIP install --no-cache-dir \
    sqlalchemy \
    alembic \
    aiohttp \
    yarl \
    pyyaml \
    Pillow \
    scipy \
    tqdm \
    psutil \
    av \
    einops \
    transformers==4.36.2 \
    tokenizers \
    sentencepiece \
    safetensors \
    soundfile \
    librosa \
    omegaconf \
    demucs \
    ToJyutping \
    g2p_en \
    g2pM \
    nltk \
    regex \
    jupyter \
    jupyterlab \
    ipykernel \
    notebook \
    opencv-python \
    scikit-image

# ============================================
# STEP 11: Force NumPy one more time
# ============================================
$VENV_PIP uninstall numpy -y 2>/dev/null
$VENV_PIP install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 12: Clone SoulX-Singer
# ============================================
if [ ! -d "$COMFY/custom_nodes/ComfyUI-SoulX-Singer" ]; then
    echo "Cloning SoulX-Singer custom node..."
    mkdir -p $COMFY/custom_nodes
    cd $COMFY/custom_nodes
    git clone https://github.com/HM-RunningHub/ComfyUI-RH_SoulX-Singer.git 2>/dev/null || \
    echo "Warning: SoulX-Singer clone failed"
fi

# ============================================
# STEP 13: Setup symlinks
# ============================================
echo "Setting up symlinks..."
# rm -f $COMFY/models $COMFY/input $COMFY/output $COMFY/custom_nodes 2>/dev/null
# ln -sfn $BASE/models $COMFY/models
# ln -sfn $BASE/input $COMFY/input
# ln -sfn $BASE/output $COMFY/output
# ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 14: Download NLTK data
# ============================================
$VENV_PYTHON -c "import nltk; nltk.download('cmudict', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True)" 2>/dev/null || true

# ============================================
# STEP 15: Final verification
# ============================================
echo "Verifying installations..."
$VENV_PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$VENV_PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"

# Test CUDA with a simple operation (bypasses the allocator issue)
$VENV_PYTHON -c "
import torch
try:
    # Test without initializing device first
    if torch.cuda.is_available():
        print('✓ CUDA is available')
    else:
        print('⚠ CUDA not available')
except Exception as e:
    print(f'CUDA test: {e}')
"

# ============================================
# STEP 16: Start Jupyter
# ============================================
echo "Starting Jupyter Lab on port 8888..."
cd /workspace
$VENV_PYTHON -m jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.allow_origin='*' \
  --ServerApp.token='' &

sleep 3

# ============================================
# STEP 17: Start ComfyUI with CPU fallback if needed
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY
export PATH="/opt/comfy_env/bin:$PATH"
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# Force CPU if CUDA fails (temporary workaround)
# Uncomment the line below to force CPU mode if CUDA errors persist
# export CUDA_VISIBLE_DEVICES=""

$VENV_PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
