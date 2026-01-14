FROM nvidia/cuda:12.8.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Helsinki

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create libcuda stub symlink for build-time linking
RUN ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/cuda/lib64/stubs/libcuda.so.1

# Clone and build llama.cpp with CUDA support
WORKDIR /opt
RUN git clone https://github.com/ggml-org/llama.cpp.git && \
    cd llama.cpp && \
    cmake -B build \
        -DGGML_CUDA=ON \
        -DLLAMA_CURL=OFF \
        -DCMAKE_CUDA_ARCHITECTURES="89;90;100;120" \
        -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -Wl,--allow-shlib-undefined" \
        -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -Wl,--allow-shlib-undefined" && \
    cmake --build build --config Release --target llama-server -j$(nproc)

# Create model directory
RUN mkdir -p /models

# Expose the server port
EXPOSE 8080

# Set working directory
WORKDIR /opt/llama.cpp

# Default command - can be overridden in docker-compose
CMD ["/opt/llama.cpp/build/bin/llama-server", \
     "-m", "/models/Qwen3VL-8B-Instruct-Q4_K_M.gguf", \
     "--mmproj", "/models/mmproj-Qwen3VL-8B-Instruct-F16.gguf", \
     "-ngl", "99", \
     "-c", "32768", \
     "--flash-attn", "on", \
     "--host", "0.0.0.0", \
     "--port", "8080"]
