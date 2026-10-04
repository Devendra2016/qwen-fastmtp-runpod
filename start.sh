#!/bin/bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/workspace/models}"

MODEL_FILE="${MODEL_FILE:-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-Q6_K_P.gguf}"
DRAFT_FILE="${DRAFT_FILE:-Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-FastMTP-32K.gguf}"

MODEL="${MODEL_DIR}/${MODEL_FILE}"
DRAFT="${MODEL_DIR}/${DRAFT_FILE}"

REPO="HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF"

CTX_SIZE="${CTX_SIZE:-262144}"
DEPTH="${MTP_DEPTH:-3}"
PORT="${PORT:-8000}"

mkdir -p "${MODEL_DIR}"

echo "================================================"
echo " Qwen3.8-27B HauhauCS Aggressive FastMTP"
echo "================================================"
echo "Model:       ${MODEL_FILE}"
echo "Draft:       ${DRAFT_FILE}"
echo "Context:     ${CTX_SIZE}"
echo "MTP depth:   ${DEPTH}"
echo "Port:        ${PORT}"
echo "================================================"

download_file() {
    local filename="$1"
    local destination="$2"

    if [ -s "${destination}" ]; then
        echo "[OK] ${filename} already exists"
        return
    fi

    echo "[DOWNLOAD] ${filename}"

    rm -f "${destination}.tmp"

    CURL_ARGS=(
        -fL
        --retry 5
        --retry-delay 5
        --connect-timeout 30
    )

    if [ -n "${HF_TOKEN:-}" ]; then
        CURL_ARGS+=(
            -H
            "Authorization: Bearer ${HF_TOKEN}"
        )
    fi

    curl "${CURL_ARGS[@]}" \
        -o "${destination}.tmp" \
        "https://huggingface.co/${REPO}/resolve/main/${filename}"

    mv "${destination}.tmp" "${destination}"

    echo "[OK] Download complete"
}

download_file "${MODEL_FILE}" "${MODEL}"
download_file "${DRAFT_FILE}" "${DRAFT}"

echo
echo "Starting patched llama-server..."
echo

exec /opt/llama/bin/llama-server \
    --model "${MODEL}" \
    --alias "Qwen3.8-27B-HauhauCS-Aggressive-Q6" \
    --spec-draft-model "${DRAFT}" \
    --spec-draft-ngl all \
    --spec-type draft-mtp \
    --spec-draft-n-max "${DEPTH}" \
    --spec-draft-p-min 0 \
    --ctx-size "${CTX_SIZE}" \
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
    --port "${PORT}"