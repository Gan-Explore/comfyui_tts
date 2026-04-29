#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

# Use the virtual environment python explicitly
VENV_PYTHON="/opt/comfy_env/bin/python"
VENV_PIP="/opt/comfy_env/bin/pip"
SYSTEM_PYTHON="/usr/bin/python3"

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

echo "Installing PyTorch and NumPy first..."
$VENV_PIP install --no-cache-dir --no-deps numpy==1.24.4
$VENV_PIP install --no-cache-dir torch==2.2.0 torchvision==0.17.0 torchaudio==2.2.0 \
    --index-url https://download.pytorch.org/whl/cu118

# ============================================
# STEP 4: Install ALL dependencies in one go
# ============================================
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
# STEP 5: Force NumPy to stay at 1.24.4
# ============================================
echo "Pinning NumPy to 1.24.4..."
$VENV_PIP uninstall numpy -y 2>/dev/null
$VENV_PIP install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 6: Install ComfyUI requirements
# ============================================
echo "Installing ComfyUI requirements..."
$VENV_PIP install --no-cache-dir -r $COMFY/requirements.txt || true

# ============================================
# STEP 7: PATCH ComfyUI for compatibility
# ============================================
echo "Patching ComfyUI..."

# Patch quant_ops.py
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
    sed -i 's/torch.uint64/torch.uint16/g' $COMFY/comfy/utils.py 2>/dev/null || true
fi

# Remove comfy_kitchen from requirements
sed -i '/comfy-kitchen/d' $COMFY/requirements.txt 2>/dev/null || true

# ============================================
# STEP 8: Clone SoulX-Singer custom node
# ============================================
if [ ! -d "$COMFY/custom_nodes/ComfyUI-SoulX-Singer" ]; then
    echo "Cloning SoulX-Singer custom node..."
    mkdir -p $COMFY/custom_nodes
    cd $COMFY/custom_nodes
    git clone https://github.com/HM-RunningHub/ComfyUI-RH_SoulX-Singer.git || \
        echo "Warning: SoulX-Singer clone failed"
fi

# ============================================
# STEP 9: Setup symlinks (remove old ones first)
# ============================================
echo "Setting up symlinks..."
rm -f $COMFY/models $COMFY/input $COMFY/output $COMFY/custom_nodes 2>/dev/null
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 10: Download NLTK data
# ============================================
$VENV_PYTHON -c "import nltk; nltk.download('cmudict', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True)" 2>/dev/null || true

# ============================================
# STEP 11: Verify sqlalchemy is installed
# ============================================
echo "Verifying installations..."
$VENV_PYTHON -c "import sqlalchemy; print(f'SQLAlchemy version: {sqlalchemy.__version__}')"
$VENV_PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$VENV_PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
$VENV_PYTHON -c "import aiohttp; print('aiohttp ok')"
$VENV_PYTHON -c "import PIL; print('Pillow ok')"

# ============================================
# STEP 12: Set environment variables
# ============================================
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# Also make sure the virtual env is used for ComfyUI
export PATH="/opt/comfy_env/bin:$PATH"

# ============================================
# STEP 13: Start Jupyter
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
# STEP 14: Start ComfyUI with explicit python
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY

if [ ! -f "main.py" ]; then
    echo "ERROR: main.py not found in $COMFY"
    exit 1
fi

# Run with explicit virtual environment python
$VENV_PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
