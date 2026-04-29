#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

# Use the virtual environment python explicitly
VENV_PYTHON="/opt/comfy_env/bin/python"
VENV_PIP="/opt/comfy_env/bin/pip"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# Show which python we're using
echo "Using Python: $VENV_PYTHON"
$VENV_PYTHON --version

# ============================================
# STEP 1: Create directory structure
# ============================================
echo "Setting up directory structure..."
mkdir -p $BASE
mkdir -p $BASE/{models,input,output,custom_nodes}

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
# STEP 3: Upgrade pip and install core dependencies
# ============================================
echo "Upgrading pip..."
$VENV_PIP install --upgrade pip setuptools wheel

# ============================================
# STEP 4: Create a compatibility patch module
# ============================================
echo "Creating compatibility patch module..."

cat > $COMFY/comfy/pytorch_compat.py << 'PYEOF'
"""
PyTorch 2.2.0 compatibility patches
"""
import torch

# Patch 1: Add missing add_safe_globals function
if not hasattr(torch.serialization, 'add_safe_globals'):
    def add_safe_globals(globals_list):
        """No-op for PyTorch 2.2.0"""
        pass
    torch.serialization.add_safe_globals = add_safe_globals
    print("✓ Patched torch.serialization.add_safe_globals")

# Patch 2: Add missing uint64 if needed
if not hasattr(torch, 'uint64'):
    torch.uint64 = torch.uint16
    print("✓ Patched torch.uint64 -> torch.uint16")

# Patch 3: Add missing dtypes if needed
if not hasattr(torch, 'float8_e4m3fn'):
    torch.float8_e4m3fn = torch.float16
if not hasattr(torch, 'float8_e5m2'):
    torch.float8_e5m2 = torch.float16

print("PyTorch compatibility patches applied")
PYEOF

# ============================================
# STEP 5: Apply the patch to main.py
# ============================================
echo "Applying compatibility patches to ComfyUI..."

# Add import to main.py
if ! grep -q "pytorch_compat" $COMFY/main.py; then
    sed -i '1iimport comfy.pytorch_compat' $COMFY/main.py
fi

# Add import to utils.py
if [ -f "$COMFY/comfy/utils.py" ]; then
    if ! grep -q "pytorch_compat" $COMFY/comfy/utils.py; then
        sed -i '1iimport comfy.pytorch_compat' $COMFY/comfy/utils.py
    fi
fi

# ============================================
# STEP 6: Install dependencies
# ============================================
echo "Installing PyTorch and NumPy..."
$VENV_PIP install --no-cache-dir --no-deps numpy==1.24.4
$VENV_PIP install --no-cache-dir torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

echo "Installing ALL required dependencies..."
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
    scikit-image \
    blake3 \
    kornia \
    spandrel \
    pydantic \
    pydantic-settings \
    PyOpenGL \
    glfw \
    simpleeval \
    gitpython \
    toml \
    cloudpickle \
    fiddle \
    beartype \
    packaging \
    six \
    requests \
    filelock \
    fsspec \
    jinja2 \
    networkx \
    sympy \
    mpmath \
    markupsafe \
    huggingface_hub \
    accelerate \
    rotary_embedding_torch

# ============================================
# STEP 7: Force NumPy to stay at 1.24.4
# ============================================
echo "Pinning NumPy to 1.24.4..."
$VENV_PIP uninstall numpy -y 2>/dev/null
$VENV_PIP install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 8: Install ComfyUI requirements
# ============================================
echo "Installing ComfyUI requirements..."
$VENV_PIP install --no-cache-dir -r $COMFY/requirements.txt || true

# ============================================
# STEP 9: PATCH ComfyUI for comfy_kitchen
# ============================================
echo "Patching ComfyUI to bypass comfy_kitchen..."

cat > $COMFY/comfy/quant_ops.py << 'PYEOF'
# Dummy quant_ops.py - bypasses comfy_kitchen dependency
class QuantizedTensor:
    pass

class _FakeCK:
    def __getattr__(self, name):
        return None

ck = _FakeCK()
PYEOF

# Patch numpy.dtypes import
if [ -f "$COMFY/comfy/utils.py" ]; then
    sed -i 's/from numpy.dtypes import Float64DType/from numpy import float64 as Float64DType/g' $COMFY/comfy/utils.py
fi

# Remove comfy_kitchen from requirements
sed -i '/comfy-kitchen/d' $COMFY/requirements.txt 2>/dev/null || true

# ============================================
# STEP 10: Clone SoulX-Singer custom node
# ============================================
if [ ! -d "$COMFY/custom_nodes/ComfyUI-SoulX-Singer" ]; then
    echo "Cloning SoulX-Singer custom node..."
    mkdir -p $COMFY/custom_nodes
    cd $COMFY/custom_nodes
    git clone https://github.com/HM-RunningHub/ComfyUI-RH_SoulX-Singer.git || \
        echo "Warning: SoulX-Singer clone failed"
fi

# ============================================
# STEP 11: Setup symlinks
# ============================================
echo "Setting up symlinks..."
rm -f $COMFY/models $COMFY/input $COMFY/output $COMFY/custom_nodes 2>/dev/null
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 12: Download NLTK data
# ============================================
$VENV_PYTHON -c "import nltk; nltk.download('cmudict', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True)" 2>/dev/null || true

# ============================================
# STEP 13: Verify installations
# ============================================
echo "Verifying installations..."
$VENV_PYTHON -c "import sqlalchemy; print(f'SQLAlchemy: {sqlalchemy.__version__}')"
$VENV_PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$VENV_PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
$VENV_PYTHON -c "import comfy.pytorch_compat; print('Compat patches loaded')"

# ============================================
# STEP 14: Set environment variables
# ============================================
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH
export PATH="/opt/comfy_env/bin:$PATH"

# ============================================
# STEP 15: Start Jupyter
# ============================================
echo "Starting Jupyter Lab on port 8888..."
$VENV_PYTHON -m jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.allow_origin='*' \
  --ServerApp.token='' &

sleep 3

# ============================================
# STEP 16: Start ComfyUI
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY

if [ ! -f "main.py" ]; then
    echo "ERROR: main.py not found in $COMFY"
    exit 1
fi

$VENV_PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
