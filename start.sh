#!/bin/bash
set -e

MODEL_DIR=/workspace/models

MODEL=$MODEL_DIR/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf
DRAFT=$MODEL_DIR/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf

mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL" ]; then
    echo "Downloading Q6_K_P..."
    curl -L \
      -H "Authorization: Bearer ${HF_TOKEN}" \
      -o "$MODEL" \
      "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf"
fi

if [ ! -f "$DRAFT" ]; then
    echo "Downloading FastMTP..."
    curl -L \
      -H "Authorization: Bearer ${HF_TOKEN}" \
      -o "$DRAFT" \
      "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"
fi

exec /opt/llama/bin/llama-server \
    --model "$MODEL" \
    --spec-draft-model "$DRAFT" \
    --spec-draft-ngl all \
    --spec-type draft-mtp \
    --spec-draft-n-max 3 \
    --spec-draft-p-min 0 \
    --ctx-size 65536 \
    --parallel 1 \
    --batch-size 2048 \
    --ubatch-size 512 \
    --n-gpu-layers all \
    --split-mode none \
    --flash-attn on \
    --no-mmap \
    --jinja \
    --reasoning on \
    --reasoning-effort xhigh \
    --reasoning-preserve \
    --reasoning-format deepseek \
    --host 0.0.0.0 \
    --port 8000
