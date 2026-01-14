#!/bin/bash
#
# Start llama-server for receipt extraction
#
# Usage:
#   ./start-llama-server.sh           # Use default model (Qwen2.5-VL)
#   ./start-llama-server.sh qwen      # Use Qwen2.5-VL-7B
#   ./start-llama-server.sh internvl  # Use InternVL3-14B (recommended)
#   ./start-llama-server.sh list      # Show available models
#

LLAMA_CPP_DIR="/home/authori/Keisuke/llama.cpp"
PORT=8080
CONTEXT_SIZE=32768

# Model selection
MODEL_CHOICE="${1:-qwen}"

case "$MODEL_CHOICE" in
    qwen|qwen2.5|default)
        MODEL_NAME="Qwen2.5-VL-7B"
        MODEL_PATH="$LLAMA_CPP_DIR/models/Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
        MMPROJ_PATH="$LLAMA_CPP_DIR/models/mmproj-F16.gguf"
        GPU_LAYERS=99
        ;;
    qwen3|qwen3vl|qwen3-8b)
        MODEL_NAME="Qwen3-VL-8B"
        MODEL_PATH="$LLAMA_CPP_DIR/models/Qwen3VL-8B-Instruct-Q4_K_M.gguf"
        MMPROJ_PATH="$LLAMA_CPP_DIR/models/mmproj-Qwen3VL-8B-Instruct-F16.gguf"
        GPU_LAYERS=99
        # Note: Qwen3-VL is the latest generation with improved OCR
        ;;
    internvl|internvl3|internvl14b)
        MODEL_NAME="InternVL3-14B-Instruct"
        MODEL_PATH="$LLAMA_CPP_DIR/models/InternVL3-14B-Instruct-Q4_K_M.gguf"
        MMPROJ_PATH="$LLAMA_CPP_DIR/models/mmproj-InternVL3-14B-Instruct-Q8_0.gguf"
        GPU_LAYERS=99
        CONTEXT_SIZE=16384  # Reduced for 14B model to fit in VRAM
        ;;
    internvl38b|internvl38)
        MODEL_NAME="InternVL3-38B"
        MODEL_PATH="$LLAMA_CPP_DIR/models/InternVL3-38B-Q4_K_M.gguf"
        MMPROJ_PATH="$LLAMA_CPP_DIR/models/mmproj-InternVL3-38B-F16.gguf"
        GPU_LAYERS=99
        CONTEXT_SIZE=8192  # Reduced for 38B model to fit in VRAM
        ;;
    list)
        echo "Available models:"
        echo "  qwen      - Qwen2.5-VL-7B (current stable)"
        echo "  qwen3     - Qwen3-VL-8B (latest, recommended)"
        echo "  internvl  - InternVL3-14B-Instruct"
        echo "  internvl38b - InternVL3-38B (large, 2GPU)"
        echo ""
        echo "Usage: ./start-llama-server.sh [model]"
        exit 0
        ;;
    *)
        echo "Unknown model: $MODEL_CHOICE"
        echo "Available options: qwen, qwen3, internvl, internvl38b, list"
        exit 1
        ;;
esac

echo "========================================"
echo "  Starting llama-server"
echo "========================================"
echo "  Model: $MODEL_NAME"
echo "  Path: $MODEL_PATH"
echo "  MMProj: $MMPROJ_PATH"
echo "  Port: $PORT"
echo "  Context: $CONTEXT_SIZE"
echo "  GPU Layers: $GPU_LAYERS"
echo "========================================"
echo ""

# Check if files exist
if [ ! -f "$MODEL_PATH" ]; then
    echo "Error: Model file not found: $MODEL_PATH"
    echo ""
    if [ "$MODEL_CHOICE" = "qwen3" ] || [ "$MODEL_CHOICE" = "qwen3vl" ] || [ "$MODEL_CHOICE" = "qwen3-8b" ]; then
        echo "To download Qwen3-VL-8B, run:"
        echo "  cd $LLAMA_CPP_DIR/models"
        echo ""
        echo "  # Main model (~5GB)"
        echo "  wget https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/Qwen3VL-8B-Instruct-Q4_K_M.gguf"
        echo ""
        echo "  # mmproj (1.16GB)"
        echo "  wget https://huggingface.co/Qwen/Qwen3-VL-8B-Instruct-GGUF/resolve/main/mmproj-Qwen3VL-8B-Instruct-F16.gguf"
    elif [ "$MODEL_CHOICE" = "internvl" ] || [ "$MODEL_CHOICE" = "internvl3" ] || [ "$MODEL_CHOICE" = "internvl14b" ]; then
        echo "To download InternVL3-14B, run:"
        echo "  cd $LLAMA_CPP_DIR/models"
        echo ""
        echo "  # Main model (9GB)"
        echo "  wget https://huggingface.co/ggml-org/InternVL3-14B-Instruct-GGUF/resolve/main/InternVL3-14B-Instruct-Q4_K_M.gguf"
        echo ""
        echo "  # mmproj (378MB)"
        echo "  wget https://huggingface.co/ggml-org/InternVL3-14B-Instruct-GGUF/resolve/main/mmproj-InternVL3-14B-Instruct-Q8_0.gguf"
    fi
    exit 1
fi

if [ ! -f "$MMPROJ_PATH" ]; then
    echo "Error: MMProj file not found: $MMPROJ_PATH"
    exit 1
fi

# Start server
$LLAMA_CPP_DIR/build/bin/llama-server \
    -m "$MODEL_PATH" \
    --mmproj "$MMPROJ_PATH" \
    -ngl $GPU_LAYERS \
    -c $CONTEXT_SIZE \
    --port $PORT \
    --host 0.0.0.0

# Note: --host 0.0.0.0 allows connections from other devices on the network
# For USB-only access, use --host 127.0.0.1 instead