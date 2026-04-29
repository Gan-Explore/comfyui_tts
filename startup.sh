#!/bin/bash

set +e

BASE="/workspace/runpod-slim"
COMFY="$BASE/ComfyUI"

PYTHON="/opt/comfy_env/bin/python"

echo "==========================================="
echo "STARTING TTS LAB (SoulX-Singer Ready)"
echo "==========================================="

# ============================================
# STEP 1: Create directory structure if it doesn't exist
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
    
    # Install ComfyUI requirements
    echo "Installing ComfyUI requirements..."
    $PYTHON -m pip install --no-cache-dir -r $COMFY/requirements.txt || true
    
    # ============================================
    # PATCH ComfyUI to bypass comfy_kitchen
    # ============================================
    echo "Patching ComfyUI to remove comfy_kitchen dependency..."
    
    # Create dummy quant_ops.py
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
    
    # Remove comfy_kitchen from requirements
    sed -i '/comfy-kitchen/d' $COMFY/requirements.txt 2>/dev/null || true
    
    # Patch memory_management.py if needed
    if [ -f "$COMFY/comfy/memory_management.py" ]; then
        sed -i 's/from comfy.quant_ops import QuantizedTensor/from comfy.quant_ops import QuantizedTensor/g' $COMFY/comfy/memory_management.py
    fi
else
    echo "ComfyUI already exists at $COMFY"
fi

# ============================================
# STEP 3: Clone SoulX-Singer custom node
# ============================================
if [ ! -d "$COMFY/custom_nodes/ComfyUI-SoulX-Singer" ]; then
    echo "Cloning SoulX-Singer custom node..."
    cd $COMFY/custom_nodes
    git clone https://github.com/HM-RunningHub/ComfyUI-RH_SoulX-Singer.git || \
        echo "Warning: SoulX-Singer clone failed"
else
    echo "SoulX-Singer already exists"
fi

# ============================================
# STEP 4: Setup symlinks
# ============================================
echo "Setting up symlinks..."
ln -sfn $BASE/models $COMFY/models
ln -sfn $BASE/input $COMFY/input
ln -sfn $BASE/output $COMFY/output
ln -sfn $BASE/custom_nodes $COMFY/custom_nodes

# ============================================
# STEP 5: Ensure NumPy is correct version
# ============================================
echo "Ensuring NumPy 1.24.4 is installed..."
$PYTHON -m pip uninstall numpy -y 2>/dev/null
$PYTHON -m pip install numpy==1.24.4 --force-reinstall --no-deps

# ============================================
# STEP 6: Start Jupyter
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
# STEP 7: Set environment variables
# ============================================
export SOULX_SINGER_ROOT=$COMFY/pretrained_models
export PYTHONPATH=$COMFY/custom_nodes/ComfyUI-SoulX-Singer:$PYTHONPATH

# ============================================
# STEP 8: Final verification
# ============================================
echo "Verifying installations..."
$PYTHON -c "import numpy; print(f'NumPy: {numpy.__version__}')"
$PYTHON -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')"

# Verify quant_ops patch works
if [ -f "$COMFY/comfy/quant_ops.py" ]; then
    $PYTHON -c "from comfy.quant_ops import QuantizedTensor; print('quant_ops patch working')"
fi

# ============================================
# STEP 9: Start ComfyUI
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
