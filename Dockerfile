FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    cmake \
    build-essential \
    libcurl4-openssl-dev \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# ------------------------------------------------------------
# HauhauCS requires this exact llama.cpp revision for FastMTP
# ------------------------------------------------------------
RUN git clone https://github.com/ggerganov/llama.cpp.git

WORKDIR /build/llama.cpp

RUN git checkout 4df29be4f4c3673f428170fda944a5b19f743bb8

# ------------------------------------------------------------
# Download and apply official HauhauCS FastMTP patch
# ------------------------------------------------------------
RUN curl -fL \
    -o HauhauCS-FastMTP-llama.cpp.patch \
    "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch"

RUN git apply --check HauhauCS-FastMTP-llama.cpp.patch

RUN git apply HauhauCS-FastMTP-llama.cpp.patch

# ------------------------------------------------------------
# CUDA build
#
# GitHub Actions has CUDA toolkit but NOT the actual NVIDIA
# driver. Link against CUDA's driver stub during build.
# RunPod will provide the real libcuda.so at runtime.
# ------------------------------------------------------------
RUN cmake -S . -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_EXE_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda" \
    -DCMAKE_SHARED_LINKER_FLAGS="-L/usr/local/cuda/lib64/stubs -lcuda"

# Build only the server we actually need.
RUN cmake --build build \
    --config Release \
    --target llama-server \
    -j2

# ------------------------------------------------------------
# Runtime
# ------------------------------------------------------------
FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    libgomp1 \
    libcurl4 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/llama.cpp/build/bin /opt/llama/bin

COPY start.sh /start.sh

RUN chmod +x /start.sh

ENV LD_LIBRARY_PATH=/opt/llama/bin:/usr/local/cuda/lib64:${LD_LIBRARY_PATH}

EXPOSE 8000

ENTRYPOINT ["/start.sh"]