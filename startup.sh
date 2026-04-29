#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# ============================================
# STEP 1: Create directory structure
# ============================================
echo "Setting up directory structure..."
mkdir -p $BASE
mkdir -p $BASE/{models,input,output,custom_nodes}

# ============================================
# STEP 2: Clone and setup ComfyUI if not exists
# ============================================
if [ ! -d "$COMFY" ]; then
    echo "ComfyUI not found. Cloning..."
    cd $BASE
    git clone https://github.com/comfyanonymous/ComfyUI.git
    echo "ComfyUI cloned successfully"
fi

# ============================================
# STEP 3: Install ALL dependencies at once
# ============================================
echo "Installing ALL required dependencies..."

$PYTHON -m pip install --no-cache-dir \
    # Core ComfyUI dependencies
    torch==2.2.0 \
    torchvision==0.17.0 \
    torchaudio==2.2.0 \
    numpy==1.24.4 \
    einops \
    transformers==4.36.2 \
    tokenizers \
    sentencepiece \
    safetensors \
    aiohttp \
    yarl \
    pyyaml \
    Pillow \
    scipy \
    tqdm \
    psutil \
    # Database
    sqlalchemy \
    alembic \
    # File handling
    av \
    # ComfyUI extras
    comfyui-frontend-package \
    comfyui-workflow-templates \
    comfyui-embedded-docs \
    comfy-aimdo \
    blake3 \
    kornia \
    spandrel \
    pydantic \
    pydantic-settings \
    PyOpenGL \
    glfw \
    # Audio processing
    soundfile \
    librosa \
    omegaconf \
    demucs \
    # Text processing
    ToJyutping \
    g2p_en \
    g2pM \
    nltk \
    regex \
    # Jupyter
    jupyter \
    jupyterlab \
    ipykernel \
    notebook \
    # Utilities
    opencv-python \
    scikit-image \
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
    einops \
    rotary_embedding_torch

# ============================================
# STEP 4: Fix any numpy upgrade attempts
# ============================================
echo "Pinning NumPy to 1.24.4..."
$PYTHON -m pip uninstall numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 5: PATCH ComfyUI to bypass comfy_kitchen
# ============================================
echo "Patching ComfyUI to remove comfy_kitchen dependency..."

if [ -f "$COMFY/comfy/quant_ops.py" ]; then
    cat > $COMFY/comfy/quant_ops.py << 'PYEOF'
# Dummy quant_ops.py - bypasses comfy_kitchen dependency
class QuantizedTensor:
    """Dummy QuantizedTensor class"""
    pass

class _FakeCK:
    def __getattr__(self, name):
        return None

ck = _FakeCK()
PYEOF
fi

# Remove comfy_kitchen from requirements.txt
sed -i '/comfy-kitchen/d' $COMFY/requirements.txt 2>/dev/null || true

# ============================================
# STEP 6: PATCH numpy.dtypes imports
# ============================================
echo "Patching ComfyUI for NumPy 1.x compatibility..."

if [ -f "$COMFY/comfy/utils.py" ]; then
    sed -i 's/from numpy.dtypes import Float64DType/from numpy import float64 as Float64DType/g' $COMFY/comfy/utils.py
    sed -i 's/torch.uint64/torch.uint16/g' $COMFY/comfy/utils.py 2>/dev/null || true
fi

# Patch all Python files for numpy.dtypes
find $COMFY -name "*.py" -exec sed -i 's/from numpy\.dtypes import /from numpy import /g' {} \; 2>/dev/null || true

# ============================================
# STEP 7: Clone SoulX-Singer custom node
# ============================================
if [ ! -d "$COMFY/custom_nodes/ComfyUI-SoulX-Singer" ]; then
    echo "Cloning SoulX-Singer custom node..."
    mkdir -p $COMFY/custom_nodes
    cd $COMFY/custom_nodes
    git clone https://github.com/HM-RunningHub/ComfyUI-RH_SoulX-Singer.git || \
        echo "Warning: SoulX-Singer clone failed"
fi

# ============================================
# STEP 8: Fix nested directory issue
# ============================================
echo "Fixing symlinks (preventing nested directories)..."

# Remove existing symlinks if they point to wrong locations
rm -f $COMFY/models $COMFY/input $COMFY/output $COMFY/custom_nodes 2>/dev/null

# Create correct symlinks
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# Verify symlinks are correct
echo "Symlink verification:"
ls -la $COMFY/ | grep -E "models|input|output|custom_nodes"

# ============================================
# STEP 9: Download NLTK data
# ============================================
echo "Downloading NLTK data..."
$PYTHON -c "import nltk; nltk.download('cmudict', quiet=True); nltk.download('averaged_perceptron_tagger', quiet=True)" 2>/dev/null || true

# ============================================
# STEP 10: Test critical imports
# ============================================
echo "Testing critical imports..."

$PYTHON -c "
import sys
missing = []
critical_modules = [
    'torch', 'numpy', 'sqlalchemy', 'aiohttp', 'transformers',
    'soundfile', 'librosa', 'PIL', 'cv2', 'skimage', 'jupyter'
]
for mod in critical_modules:
    try:
        __import__(mod)
        print(f'✓ {mod}')
    except ImportError as e:
        print(f'✗ {mod}: {e}')
        missing.append(mod)

if missing:
    print(f'WARNING: Missing modules: {missing}')
else:
    print('All critical modules imported successfully!')
"

# ============================================
# STEP 11: Start Jupyter
# ============================================
echo "Starting Jupyter Lab on port 8888..."
$PYTHON -m jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.allow_origin='*' \
  --ServerApp.token='' &

sleep 3

# ============================================
# STEP 12: Set environment variables
# ============================================
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# ============================================
# STEP 13: Final verification
# ============================================
echo "Final verification..."
$PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"
$PYTHON -c "import sqlalchemy; print(f'SQLAlchemy: {sqlalchemy.__version__}')"

# ============================================
# STEP 14: Start ComfyUI
# ============================================
echo "Starting ComfyUI on port 8188..."
cd $COMFY

if [ ! -f "main.py" ]; then
    echo "ERROR: main.py not found in $COMFY"
    exit 1
fi

$PYTHON main.py --listen 0.0.0.0 --port 8188

echo "ComfyUI exited. Debug mode active."
sleep infinity
