# Use RunPod's official ComfyUI base image
# This avoids all the compatibility issues we've been fighting
FROM runpod/worker-comfyui:3.0.0-base

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# SoulX-Singer and TTS dependencies
RUN pip install --no-cache-dir \
    ToJyutping==3.2.0 \
    g2p_en==2.1.0 \
    g2pM==0.1.2.5 \
    demucs \
    transformers==4.36.2 \
    accelerate==0.33.0 \
    einops==0.8.0 \
    soundfile==0.12.1 \
    scipy==1.14.1 \
    librosa==0.10.2 \
    omegaconf==2.3.0 \
    opencv-python==4.8.1.78 \
    scikit-image==0.21.0 \
    nltk==3.8.1 \
    regex==2024.11.6 \
    jupyter jupyterlab ipykernel

# Download NLTK data
RUN python -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# Cache directories
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

COPY startup.sh /opt/startup.sh
RUN chmod +x /opt/startup.sh

ENTRYPOINT ["/opt/startup.sh"]
