#!/bin/bash
# ==========================================
# [NEXUS_ULTRA_V2] 赛博先知 重装甲特化版 (8核64G + 全局内网穿透)
# ==========================================

# 1. 密钥安全检查
if [ -z "$CF_TOKEN" ]; then
    echo "[!!FATAL!!] 核心密钥缺失！请使用 export CF_TOKEN='你的密钥' 注入。"
    exit 1
fi

WORK_DIR="/home/user/projects/ai_core"
MODEL_NAME="gemma-4-26b-moe-q4_k_m.gguf"
# 预留 Gemma 4 26B 的下载地址
MODEL_URL="https://huggingface.co/google/gemma-4-26b-moe-GGUF/resolve/main/${MODEL_NAME}"
RAM_DISK="/dev/shm"

mkdir -p $WORK_DIR
cd $WORK_DIR

# 2. 准备穿透探针和推理引擎 (存放在物理硬盘，占用极小)
echo "[NEXUS] 正在检查穿透探针与引擎核心..."
if [ ! -f "cloudflared" ]; then
    wget -qO cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64
    chmod +x cloudflared
fi

if [ ! -f "llama-server" ]; then
    # 实际使用时替换为最新的 llama.cpp release 链接
    wget -q https://github.com/ggerganov/llama.cpp/releases/latest/download/llama-bXXXX-bin-linux-avx2-x64.zip
    unzip -j llama-*.zip '**/llama-server' && rm llama-*.zip
    chmod +x llama-server
fi

# 3. 战场转移：利用 64GB 内存池建立 RAM Disk 缓存
echo "[NEXUS] 正在验证内存盘 (RAM Disk) 状态..."
if [ ! -f "${RAM_DISK}/${MODEL_NAME}" ]; then
    echo "[NEXUS] 正在拉取 Gemma 4 26B MoE 核心 (约 16GB) 到内存盘，避开物理硬盘限制..."
    # 直接写入 /dev/shm
    curl -L -o "${RAM_DISK}/${MODEL_NAME}" "$MODEL_URL" 
fi

# 4. 引擎全功率点火 (从内存极速读取)
echo "[NEXUS] 8核引擎全功率点火！"
# 注意：路径指向了 ${RAM_DISK}
nohup ./llama-server -m "${RAM_DISK}/${MODEL_NAME}" \
    -c 8192 --host 0.0.0.0 --port 8080 \
    -t 8 --mlock > /tmp/gemma_ultra.log 2>&1 &

# 5. 打通公网隧道
echo "[NEXUS] 正在打通全局内网隧道，强行撕开 BTP 防火墙..."
nohup ./cloudflared tunnel run --token $CF_TOKEN > /tmp/tunnel.log 2>&1 &

echo "[NEXUS] 重装甲已上线，并已暴露至公网！Gemma 4 26B 随时接受外部 API 调用！面甲已降下。"
