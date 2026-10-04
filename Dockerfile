FROM nvidia/cuda:12.8.1-devel-ubuntu24.04 AS builder

RUN apt-get update && apt-get install -y \
    git \
    curl \
    cmake \
    build-essential \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone https://github.com/ggerganov/llama.cpp.git

WORKDIR /build/llama.cpp

# Exact runtime commit specified by HauhauCS FastMTP
RUN git checkout 4df29be4f4c3673f428170fda944a5b19f743bb8

# Download FastMTP llama.cpp patch
RUN curl -fL \
    -o HauhauCS-FastMTP.patch \
    "https://huggingface.co/HauhauCS/Qwen3.8-27B-Uncensored-HauhauCS-Aggressive-MTP-GGUF/resolve/main/HauhauCS-FastMTP-llama.cpp.patch"

# Verify and apply patch
RUN git apply --check HauhauCS-FastMTP.patch
RUN git apply HauhauCS-FastMTP.patch

# Configure CUDA build
RUN cmake -S . -B build \
    -DGGML_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release

# Only build llama-server.
# -j2 avoids exhausting GitHub runner RAM during CUDA/C++ compilation.
RUN cmake --build build \
    --config Release \
    --target llama-server \
    -j2


# -------------------------------
# Runtime image
# -------------------------------

FROM nvidia/cuda:12.8.1-runtime-ubuntu24.04

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/llama.cpp/build/bin /opt/llama/bin

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 8000

ENTRYPOINT ["/start.sh"]