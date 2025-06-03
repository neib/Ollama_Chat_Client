#!/bin/bash

# Install NVIDIA Container Toolkit
# Add NVIDIA repository + GPG key
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list    
  
# Update and install toolkit
sudo apt update && sudo apt install nvidia-container-toolkit

#Configure the container runtime by using the nvidia-ctk command:
sudo nvidia-ctk runtime configure --runtime=docker

# Restart Docker daemon
sudo service docker restart

# Check
### docker run --rm --gpus all nvidia/cuda:11.8.0-base-ubuntu22.04 nvidia-smi
###     -> If this displays GPU information, the toolkit is correctly installed.
# docker run --rm --gpus all nvidia/cuda:11.8-base nvidia-smi

# Build and run
# sudo docker build -t nvidia-cuda .
# sudo docker run --gpus all -it --rm -v ~/Ollama/workspace:/workspace nvidia-cuda
