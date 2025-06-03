# syntax=docker/dockerfile:1.4
# Use the official CUDA 11.8 runtime on Ubuntu 22.04
ARG CUDA_VERSION=12.2.0
ARG UBUNTU_BASE=ubuntu22.04
ARG TARGETARCH

#FROM --platform=linux/${TARGETARCH} nvidia/cuda:${CUDA_VERSION}-runtime-${UBUNTU_BASE}
# CUDA image base without explicit multi-arch (avoids error if TARGETARCH is empty)
FROM nvidia/cuda:${CUDA_VERSION}-runtime-${UBUNTU_BASE}


# NVIDIA variables to expose GPU
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    NVIDIA_REQUIRE_CUDA="cuda>=12.2"

# With APT cache for faster rebuilds
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      ca-certificates \
      curl \
      netcat-openbsd \
      jq \
    && rm -rf /var/lib/apt/lists/*

# Install Ollama
RUN curl -fsSL https://ollama.com/install.sh | sh

# Useful for the ‘compose’ key
RUN apt-get update && apt-get install -y locales \
    && sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8



# Preparing the Docker/Host link
RUN mkdir -p /workspace/.ollama
WORKDIR /workspace

# Create Ollama conf in /workspace instead of /root (default path)
RUN rm -rf /root/.ollama \
&& ln -s /workspace/.ollama /root/.ollama

# Command startup
CMD ["./ollama_client.sh"]
#CMD ["bash"]
