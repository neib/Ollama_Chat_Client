# Ollama_Chat_Client
A pretty command-line client

Installation of nvidia-cuda is optional, and the tool should work in any Linux container provided you've installed these tools:
- ca-certificates
- curl
- netcat-openbsd
- jq

The Dockerfile is prepared for NVIDIA-CUDA installation

# Running
First run the install.sh script to get the NVIDIA Container Toolkit
Then build the Docker image with Dockerfile 
  - startup with "bash" or "ollama_client.sh.fake to last config:
    ex: ollamma pull <model>
    etc.
