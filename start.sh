#!/bin/bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/workspace/models}"

MODEL_FILE="Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf"
DRAFT_FILE="Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf"

MODEL="${MODEL_DIR}/${MODEL_FILE}"
DRAFT="${MODEL_DIR}/${DRAFT_FILE}"

REPO="HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF"

mkdir -p "${MODEL_DIR}"

echo "============================================"
echo " Qwen3.8 27B HauhauCS FastMTP"
echo " Target: Q6_K_P"
echo " Context: 262144"
echo " FastMTP depth: 3"
echo "============================================"

download_file() {
    local filename="$1"
    local destination="$2"

    if [ -f "${destination}" ]; then
        echo "Already downloaded: ${filename}"
        return
    fi

    echo "Downloading ${filename}..."

    if [ -n "${HF_TOKEN:-}" ]; then
        curl -fL \
            --retry 5 \
            --retry-delay 5 \
            -H "Authorization: Bearer ${HF_TOKEN}" \
            -o "${destination}.tmp" \
            "https://huggingface.co/${REPO}/resolve/main/${filename}"
    else
        curl -fL \
            --retry 5 \
            --retry-delay 5 \
            -o "${destination}.tmp" \
            "https://huggingface.co/${REPO}/resolve/main/${filename}"
    fi

    mv "${destination}.tmp" "${destination}"

    echo "Downloaded ${filename}"
}

download_file "${MODEL_FILE}" "${MODEL}"
download_file "${DRAFT_FILE}" "${DRAFT}"

echo ""
echo "Starting llama-server..."
echo ""

exec /opt/llama/bin/llama-server \
    --model "${MODEL}" \
    --alias "Qwen3.8-27B-HauhauCS-Aggressive-Q6" \
    --spec-draft-model "${DRAFT}" \
    --spec-draft-ngl all \
    --spec-type draft-mtp \
    --spec-draft-n-max 3 \
    --spec-draft-p-min 0 \
    --ctx-size 262144 \
    --parallel 1 \
    --batch-size 2048 \
    --ubatch-size 512 \
    --n-gpu-layers all \
    --split-mode none \
    --flash-attn on \
    --no-mmap \
    --temp 1.0 \
    --top-k 20 \
    --top-p 0.95 \
    --min-p 0 \
    --presence-penalty 0 \
    --repeat-penalty 1.0 \
    --jinja \
    --reasoning on \
    --reasoning-effort xhigh \
    --reasoning-preserve \
    --reasoning-format deepseek \
    --host 0.0.0.0 \
    --port 8000