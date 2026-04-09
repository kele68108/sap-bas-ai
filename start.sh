#!/usr/bin/env bash

# ==========================================================
# SAP-BAS环境一键部署[x-tunnel+vless-argo]代理协议开机自启一键脚本
# ==========================================================

# ---------------------------------------------------------
# 🔻 绝密配置区 (变量直填) 🔻
# ---------------------------------------------------------
# 【系统保活探针】
HTTP_PORT="8080"

# 【VLESS+ARGO 代理配置】
UUID="6948adff-5e1e-4f52-9c9c-11b707390b8b"
VLESS_DOMAIN="10.oxxx.qzz.io"
VLESS_ARGO_TOKEN="eyJhIjoiNTA0NmI1ODdjNmU0YmRhN2FlNTM2ZGZjZGVjM2M1NDkiLCJ0IjoiYjQ5YmNjOWEtYzE5OS00MTc3LWEwZGEtZjMwMmNmNDMzNGQ4IiwicyI6Ik0yVTRPV0kwTURRdE9UUmhZUzAwTldKaUxXRXlPV0V0WldObVlXUTJZVEJrWVRBMSJ9"
VLESS_PORT="8001"
CFIP="sin.cfip.oxxxx.de"
CFPORT="443"
VLESS_NAME="SAP-BAS"

# 【X-Tunnel 代理配置 】
X_TOKEN="kele666"
XT_ARGO_TOKEN="eyJhIjoiNTA0NmI1ODdjNmU0YmRhN2FlNTM2ZGZjZGVjM2M1NDkiLCJ0IjoiZmJkNWRjOTQtYzE1Zi00MGY4LTk5YmItNzc0OTZjOTlmMWI3IiwicyI6Ik9UazVNbVZrTkdVdFpUVTBZaTAwWW1NMkxUbGhNV1l0Wm1NMk5EWm1aREJpWkdaayJ9"
XT_INTERNAL_PORT="8002"
# ---------------------------------------------------------

WORK_DIR="/tmp/sap_core"

echo "[+] 启动清理程序，清除旧的僵尸进程..."
fuser -k -9 $HTTP_PORT/tcp $VLESS_PORT/tcp 3002/tcp $XT_INTERNAL_PORT/tcp >/dev/null 2>&1 || true
pkill -9 -f "cloudflared" >/dev/null 2>&1 || true
pkill -9 -f "web" >/dev/null 2>&1 || true
pkill -9 -f "x-tunnel" >/dev/null 2>&1 || true

# --- 1. 环境准备 ---
mkdir -p "$WORK_DIR"
rm -f "$WORK_DIR"/* 2>/dev/null

WEB_NAME=$(tr -dc a-z </dev/urandom | head -c 6)
XT_NAME=$(tr -dc a-z0-9 </dev/urandom | head -c 8)
CF_NAME=$(tr -dc a-z0-9 </dev/urandom | head -c 8)

WEB_PATH="$WORK_DIR/$WEB_NAME"
XT_PATH="$WORK_DIR/$XT_NAME"
CF_PATH="$WORK_DIR/$CF_NAME"
CONFIG_PATH="$WORK_DIR/config.json"
SUB_PATH_FILE="$WORK_DIR/sub.txt"

# --- 2. 启动 HTTP 健康检查探针 ---
echo "[+] 伪造 HTTP 健康探针 (端口: $HTTP_PORT)..."
nohup python3 -c "
import http.server, socketserver
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args): pass
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'BAS Tunnel Service is running.')
try:
    socketserver.TCPServer(('', $HTTP_PORT), Handler).serve_forever()
except Exception:
    pass
" >/dev/null 2>&1 &

# --- 3. 生成极致纯净的 VLESS 代理配置 (修复语法崩溃Bug) ---
cat <<EOF > "$CONFIG_PATH"
{
  "log": {"access": "/dev/null", "error": "/dev/null", "loglevel": "warning"},
  "inbounds": [
    {
      "port": $VLESS_PORT, "protocol": "vless",
      "settings": {
        "clients": [{"id": "$UUID", "level": 0}],
        "decryption": "none",
        "fallbacks": [{"path": "/vless-argo", "dest": 3002}]
      },
      "streamSettings": {"network": "tcp", "security": "none"}
    },
    {
      "port": 3002, "listen": "127.0.0.1", "protocol": "vless",
      "settings": {"clients": [{"id": "$UUID", "level": 0}], "decryption": "none"},
      "streamSettings": {
        "network": "ws", "security": "none",
        "wsSettings": {"path": "/vless-argo", "maxEarlyData": 2560, "earlyDataHeaderName": "Sec-WebSocket-Protocol"}
      },
      "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
    }
  ],
  "outbounds": [{"protocol": "freedom", "tag": "direct"}, {"protocol": "blackhole", "tag": "block"}]
}
EOF

# --- 4. 下载统一核心组件 ---
echo "[+] 正在下载依赖..."
curl -sL -o "$WEB_PATH" "https://github.com/guoziyou/SOCKS5/raw/refs/heads/main/web"
curl -sL -o "$XT_PATH" "https://github.com/kele68108/sap-x-tunnel/raw/refs/heads/main/x-tunnel-linux-amd64"
curl -sL -o "$CF_PATH" "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64"
chmod 755 "$WEB_PATH" "$XT_PATH" "$CF_PATH"

# --- 5. 双轨点火 (后台静默拉起) ---
echo "[+] 启动 VLESS 代理核心..."
nohup "$WEB_PATH" -c "$CONFIG_PATH" > /dev/null 2>&1 &
sleep 1

echo "[+] 打通 VLESS ARGO 隧道..."
nohup "$CF_PATH" tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token "$VLESS_ARGO_TOKEN" > /dev/null 2>&1 &
sleep 1

echo "[+] 启动 X-Tunnel 核心程序..."
nohup "$XT_PATH" -l "ws://127.0.0.1:${XT_INTERNAL_PORT}" -token "$X_TOKEN" >/dev/null 2>&1 &
sleep 1

echo "[+] 打通 X-Tunnel ARGO 隧道..."
nohup "$CF_PATH" tunnel --edge-ip-version auto --no-autoupdate run --token "$XT_ARGO_TOKEN" >/dev/null 2>&1 &

# --- 6. 生成订阅链接 ---
VLESS_LINK="vless://${UUID}@${CFIP}:${CFPORT}?encryption=none&security=tls&sni=${VLESS_DOMAIN}&type=ws&host=${VLESS_DOMAIN}&path=%2Fvless-argo%3Fed%3D2560#${VLESS_NAME}"
VLESS_BASE64=$(echo -n "$VLESS_LINK" | base64 | tr -d '\n')
echo "$VLESS_BASE64" > "$SUB_PATH_FILE"
echo "=================================================="
echo "
echo "您的 VLESS 节点订阅内容 (Base64):"
echo "$VLESS_BASE64"
echo "
echo "=================================================="
echo "
echo "X-Tunnel 服务地址为您设置的 XT_ARGO_TOKEN 对应域名"
echo "
echo "
echo "=================================================="

# --- 7. 永生印记：写入 ~/.bashrc 实现开机自启 ---
SCRIPT_ABS_PATH=$(readlink -f "$0")
if ! grep -q "nexus_tunnel" ~/.bashrc; then
    echo "[+] 正在写入开机自启 (~/.bashrc)..."
    echo "nohup $SCRIPT_ABS_PATH >/dev/null 2>&1 &" >> ~/.bashrc
fi

# --- 8. 阅后即焚 ---
(
    sleep 90
    rm -f "$CONFIG_PATH" "$WEB_PATH" "$XT_PATH" "$CF_PATH" "$SUB_PATH_FILE" >/dev/null 2>&1
) &

echo "[+] 节点已部署完毕！服务隐匿至后台。"
echo "[+] 您现在可以安全地关闭终端了。"
exit 0
