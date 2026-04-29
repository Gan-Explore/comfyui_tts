# Use the community-maintained RunPod ComfyUI base image
FROM timpietruskyblibla/runpod-worker-comfy:3.0.0-base

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# SoulX-Singer and TTS dependencies
RUN pip3 install --no-cache-dir \
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

# Download NLTK data (using python3)
RUN python3 -c "import nltk; nltk.download('cmudict'); nltk.download('averaged_perceptron_tagger')"

# Set cache directories
ENV HF_HOME=/workspace/runpod-slim/model_cache/huggingface
ENV TRANSFORMERS_CACHE=/workspace/runpod-slim/model_cache/huggingface
ENV NLTK_DATA=/workspace/runpod-slim/nltk_data

EXPOSE 8188 8888

# The base image already has an entrypoint
# We just need to add our custom startup
COPY startup.sh /opt/custom-startup.sh
RUN chmod +x /opt/custom-startup.sh

# The base image's entrypoint will run scripts in /etc/cont-init.d and /etc/services.d
# Create a service for Jupyter
RUN mkdir -p /etc/services.d/jupyter
RUN echo '#!/usr/bin/with-contenv bash\n\
exec jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --allow-root --ServerApp.token="" --ServerApp.allow_origin="*"' > /etc/services.d/jupyter/run
RUN chmod +x /etc/services.d/jupyter/run
