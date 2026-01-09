#!/bin/bash
#
# Start llama-server for receipt extraction
#
# Prerequisites:
#   - llama.cpp built with CUDA support
#   - Qwen2.5-VL model files downloaded
#
# Usage:
#   ./start-llama-server.sh

LLAMA_CPP_DIR="/home/authori/Keisuke/llama.cpp"
MODEL_PATH="$LLAMA_CPP_DIR/models/Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
MMPROJ_PATH="$LLAMA_CPP_DIR/models/mmproj-F16.gguf"
PORT=8080

echo "Starting llama-server..."
echo "  Model: $MODEL_PATH"
echo "  MMProj: $MMPROJ_PATH"
echo "  Port: $PORT"
echo ""

# Check if files exist
if [ ! -f "$MODEL_PATH" ]; then
    echo "Error: Model file not found: $MODEL_PATH"
    exit 1
fi

if [ ! -f "$MMPROJ_PATH" ]; then
    echo "Error: MMProj file not found: $MMPROJ_PATH"
    exit 1
fi

# Start server
# -ngl 99: Offload all layers to GPU
# -c 4096: Context size
# --port: HTTP port
$LLAMA_CPP_DIR/build/bin/llama-server \
    -m "$MODEL_PATH" \
    --mmproj "$MMPROJ_PATH" \
    -ngl 99 \
    -c 4096 \
    --port $PORT \
    --host 0.0.0.0

# Note: --host 0.0.0.0 allows connections from other devices on the network
# For USB-only access, use --host 127.0.0.1 instead
