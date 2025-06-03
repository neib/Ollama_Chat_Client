#!/bin/bash

# Check local:~/Ollama/workspace/.ollama to link docker:/root/.ollama
directory="workspace/.ollama"
if [ ! -d "$directory" ]; then      
  mkdir -p $directory
fi

# Mount local:~/Ollama/workspace to docker:/workspace
sudo docker run --gpus all -it --rm -v ~/Ollama/workspace:/workspace nvidia-cuda
