FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS builder

RUN apt-get update && apt-get install -y \
    git curl cmake build-essential libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone https://github.com/ggerganov/llama.cpp.git && \
    cd llama.cpp && \
    git checkout 4df29be4f4c3673f428170fda944a5b19f743bb8 && \
    curl -L -o HauhauCS-FastMTP.patch \
      https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch && \
    git apply --check HauhauCS-FastMTP.patch && \
    git apply HauhauCS-FastMTP.patch && \
    cmake -S . -B build \
      -DGGML_CUDA=ON \
      -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --config Release -j$(nproc)

FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

RUN apt-get update && apt-get install -y \
    curl ca-certificates libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/llama.cpp/build/bin /opt/llama/bin
COPY start.sh /start.sh

RUN chmod +x /start.sh

EXPOSE 8000

ENTRYPOINT ["/start.sh"]
