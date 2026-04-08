cat << 'EOF' > ~/run_v7.sh
#!/bin/bash
# ==========================================
# [NEXUS_ULTRA_V7] 返璞归真版 (1.6GB Gemma 2 2B)
# 放弃幻想，回归物理硬盘，榨干 8 核算力！
# ==========================================

if [ -z "$CF_TOKEN" ]; then
    echo "[!!FATAL!!] 核心密钥缺失！"
    exit 1
fi

WORK_DIR="/home/user/projects/ai_core"
# 换用 1.1GB 的 Qwen2-1.5B 模型，完美适配 3.9GB 硬盘
MODEL_NAME="qwen2-1_5b-instruct-q4_k_m.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2-1.5B-Instruct-GGUF/resolve/main/qwen2-1_5b-instruct-q4_k_m.gguf"

mkdir -p $WORK_DIR
cd $WORK_DIR

echo "[NEXUS] 正在获取探针与完整引擎核心..."
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

if [ ! -f "libllama.so" ]; then
    rm -f llama-server
    echo "[NEXUS] 下载并解压完整的引擎组件..."
    STABLE_LLAMA_URL="https://github.com/ggerganov/llama.cpp/releases/download/b4618/llama-b4618-bin-ubuntu-x64.zip"
    wget -qO llama.zip "$STABLE_LLAMA_URL"
    unzip -q -o -j llama.zip '*llama-server' '*.so' && rm llama.zip
    chmod +x llama-server
fi

echo "[NEXUS] 正在清理所有历史遗留的管道和坏死文件..."
pkill -f llama-server
pkill -f cloudflared
rm -f /tmp/gemma_stream
rm -f /dev/shm/gemma*
# 清理可能占满硬盘的 npm/pip 缓存以释放空间
rm -rf ~/.cache/pip/* rm -rf ~/.npm/_cacache/*

echo "[NEXUS] 正在将 1.6GB 轻量核弹安全降落至物理硬盘..."
# 使用 -C - 支持断点续传，防止网络波动
if [ ! -f "$MODEL_NAME" ]; then
    curl -L -C - -o "$MODEL_NAME" "$MODEL_URL" 
fi

echo "[NEXUS] 8核引擎全功率点火！(使用原生 mmap 映射至 64G 内存)"
# 回归正常的 mmap 模式，让 Linux 自己管理内存
nohup env LD_LIBRARY_PATH=$PWD ./llama-server -m "$MODEL_NAME" \
    -c 4096 --host 0.0.0.0 --port 8080 \
    -t 8 > /tmp/gemma_ultra.log 2>&1 &

echo "[NEXUS] 正在撕开 BTP 防火墙..."
nohup ./cloudflared tunnel run --token $CF_TOKEN > /tmp/tunnel.log 2>&1 &

echo "[NEXUS] 面甲降下！请监控日志等待 HTTP server listening..."
EOF

chmod +x ~/run_v7.sh
~/run_v7.sh
