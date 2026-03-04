#!/bin/bash
#================================================================
# 05_setup_autodl.sh
# AutoDL 容器专用网络配置脚本
# 功能：配置 Nginx 监听 6006 端口，统一代理 Dify Web + API
#      重新构建前端，使 API 请求指向正确的外部地址
# 使用方法: sudo bash scripts/05_setup_autodl.sh
#================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

DIFY_DIR="${DIFY_DIR:-/opt/dify}"
DIFY_API_PORT="${DIFY_API_PORT:-5001}"
DIFY_WEB_PORT="${DIFY_WEB_PORT:-3000}"
PUBLIC_PORT="${PUBLIC_PORT:-6006}"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   AutoDL 网络配置                                ║"
echo "║   Nginx 外部端口: ${PUBLIC_PORT}                       ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

echo "=========================================="
echo "  [Step 1/4] 安装 Nginx..."
echo "=========================================="
if ! command -v nginx &> /dev/null; then
    apt-get update -qq
    apt-get install -y nginx
    echo "Nginx 安装完成"
else
    echo "Nginx 已安装: $(nginx -v 2>&1)"
fi

echo "=========================================="
echo "  [Step 2/4] 获取服务器公网 IP..."
echo "=========================================="
SERVER_IP=$(curl -s --max-time 10 ifconfig.me 2>/dev/null || \
            curl -s --max-time 10 ip.sb 2>/dev/null || \
            curl -s --max-time 10 api.ipify.org 2>/dev/null || \
            hostname -I | awk '{print $1}')
echo "公网 IP: ${SERVER_IP}"

echo "=========================================="
echo "  [Step 3/4] 配置 Nginx (端口 ${PUBLIC_PORT})..."
echo "=========================================="
cat > /etc/nginx/sites-available/dify << NGINXEOF
# Dify AutoDL 部署配置
# 外部端口 ${PUBLIC_PORT} 统一代理 Dify Web + API

server {
    listen ${PUBLIC_PORT};
    server_name _;

    # 文件上传大小（面部照片）
    client_max_body_size 15M;

    # 超时（大模型推理需要较长时间）
    proxy_read_timeout 300s;
    proxy_connect_timeout 60s;
    proxy_send_timeout 300s;

    # Dify API - Console
    location /console/api/ {
        proxy_pass http://127.0.0.1:${DIFY_API_PORT}/console/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
    }

    # Dify API - Public
    location /api/ {
        proxy_pass http://127.0.0.1:${DIFY_API_PORT}/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    # Dify API - Service
    location /v1/ {
        proxy_pass http://127.0.0.1:${DIFY_API_PORT}/v1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    # Dify 文件服务
    location /files/ {
        proxy_pass http://127.0.0.1:${DIFY_API_PORT}/files/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    # Dify Web 前端（其余所有路径）
    location / {
        proxy_pass http://127.0.0.1:${DIFY_WEB_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }
}
NGINXEOF

# 启用配置、移除默认站点
ln -sf /etc/nginx/sites-available/dify /etc/nginx/sites-enabled/dify
rm -f /etc/nginx/sites-enabled/default

# 测试并重启
nginx -t
service nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true
echo "Nginx 配置完成，监听端口 ${PUBLIC_PORT}"

echo "=========================================="
echo "  [Step 4/4] 重建 Dify 前端..."
echo "=========================================="

# ---- 4a: 确保 Node.js >= 22 ----
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/v\([0-9]*\).*/\1/')
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 22 ]; then
    echo "  当前 Node.js 版本: $(node --version 2>/dev/null || echo '未安装')"
    echo "  Dify 1.13+ 需要 Node.js >=22，正在升级..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
    npm install -g pnpm@9 --force
    echo "  Node.js 升级完成: $(node --version)"
else
    echo "  Node.js 版本满足要求: $(node --version)"
fi

# ---- 4b: 更新前端环境变量（使用相对路径，兼容 SSH 隧道/AutoDL 代理等所有访问方式）----
cat > "${DIFY_DIR}/web/.env.local" << 'ENVEOF'
# AutoDL 环境配置 - 由 05_setup_autodl.sh 自动生成
# 使用相对路径，浏览器 API 请求自动跟随当前访问地址，兼容所有访问方式
NEXT_PUBLIC_API_PREFIX=/console/api
NEXT_PUBLIC_PUBLIC_API_PREFIX=/api
NEXT_PUBLIC_DEPLOY_ENV=PRODUCTION
NEXT_PUBLIC_EDITION=SELF_HOSTED
NEXT_PUBLIC_SENTRY_DSN=
ENVEOF
echo "  前端配置已写入 ${DIFY_DIR}/web/.env.local（API 使用相对路径）"

# ---- 4c: 停止旧进程 ----
pkill -f "next.*start" 2>/dev/null || true
sleep 2

# ---- 4d: 安装依赖 + 构建 ----
cd "${DIFY_DIR}/web"
echo "  安装前端依赖（node_modules）..."
if [ -f "pnpm-lock.yaml" ]; then
    pnpm install --frozen-lockfile 2>&1 | tail -3 || pnpm install 2>&1 | tail -3
elif [ -f "yarn.lock" ]; then
    yarn install --frozen-lockfile 2>&1 | tail -3
else
    npm install 2>&1 | tail -3
fi

echo "  开始构建前端（约需 3-8 分钟）..."
if [ -f "pnpm-lock.yaml" ]; then
    pnpm build 2>&1 | tail -8
elif [ -f "yarn.lock" ]; then
    yarn build 2>&1 | tail -8
else
    npm run build 2>&1 | tail -8
fi
echo "  前端构建完成"

# ---- 4e: 启动 Web ----
echo "  启动 Dify Web..."
mkdir -p /var/log/dify
if [ -f "pnpm-lock.yaml" ]; then
    nohup pnpm start -p ${DIFY_WEB_PORT} -H 0.0.0.0 > /var/log/dify/web.log 2>&1 &
elif [ -f "yarn.lock" ]; then
    nohup yarn start -p ${DIFY_WEB_PORT} -H 0.0.0.0 > /var/log/dify/web.log 2>&1 &
else
    nohup npm start -- -p ${DIFY_WEB_PORT} -H 0.0.0.0 > /var/log/dify/web.log 2>&1 &
fi

echo "等待服务就绪..."
sleep 10

echo ""
echo "=========================================="
echo "  验证服务..."
echo "=========================================="
WEB_OK=$(curl -s --max-time 5 http://localhost:${DIFY_WEB_PORT} > /dev/null 2>&1 && echo "✅ 运行中" || echo "❌ 未就绪（请稍等再检查）")
NGINX_OK=$(curl -s --max-time 5 http://localhost:${PUBLIC_PORT} > /dev/null 2>&1 && echo "✅ 运行中" || echo "❌ 未就绪")
API_OK=$(curl -s --max-time 5 http://localhost:${DIFY_API_PORT}/health > /dev/null 2>&1 && echo "✅ 运行中" || echo "❌ 未运行")

echo "  Dify Web  (内部 ${DIFY_WEB_PORT}) : ${WEB_OK}"
echo "  Nginx     (外部 ${PUBLIC_PORT})   : ${NGINX_OK}"
echo "  Dify API  (内部 ${DIFY_API_PORT}) : ${API_OK}"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   配置完成！                                     ║"
echo "║                                                  ║"
echo "║   访问地址: http://${SERVER_IP}:${PUBLIC_PORT}          ║"
echo "║                                                  ║"
echo "║   AutoDL 控制台点击 ${PUBLIC_PORT} 端口链接也可直接访问  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "  初次访问请到 /install 页面设置管理员账号"
echo "  http://${SERVER_IP}:${PUBLIC_PORT}/install"
