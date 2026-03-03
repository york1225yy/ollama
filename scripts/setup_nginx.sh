#!/bin/bash
#================================================================
# setup_nginx.sh - 可选：Nginx 反向代理配置
# 使用方法: sudo bash setup_nginx.sh
# 此脚本配置 Nginx 作为反向代理，功能：
#   - 统一入口 (80端口)
#   - 支持 HTTPS (可选)
#   - 文件上传大小限制调整
#================================================================

set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$PROJECT_DIR/configs/env.conf" 2>/dev/null || true

DIFY_API_PORT="${DIFY_API_PORT:-5001}"
DIFY_WEB_PORT="${DIFY_WEB_PORT:-3000}"
SERVER_IP="${SERVER_IP:-0.0.0.0}"

echo "=========================================="
echo "  安装和配置 Nginx 反向代理"
echo "=========================================="

# 安装 Nginx
if ! command -v nginx &> /dev/null; then
    apt-get update
    apt-get install -y nginx
fi

# 创建 Nginx 配置
cat > /etc/nginx/sites-available/dify << NGINXEOF
# Dify AI 面部健康分析系统 - Nginx 配置
# 统一使用 80 端口对外提供服务

upstream dify_web {
    server 127.0.0.1:${DIFY_WEB_PORT};
}

upstream dify_api {
    server 127.0.0.1:${DIFY_API_PORT};
}

server {
    listen 80;
    server_name _;

    # 文件上传大小限制 (图片上传需要)
    client_max_body_size 15M;

    # 请求超时设置 (大模型推理较慢)
    proxy_read_timeout 300s;
    proxy_connect_timeout 60s;
    proxy_send_timeout 300s;

    # Dify Web 前端
    location / {
        proxy_pass http://dify_web;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # WebSocket 支持 (SSE流式输出)
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }

    # Dify API
    location /console/api/ {
        proxy_pass http://dify_api/console/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }

    location /api/ {
        proxy_pass http://dify_api/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_buffering off;
    }

    location /v1/ {
        proxy_pass http://dify_api/v1/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        proxy_http_version 1.1;
        proxy_buffering off;
    }

    location /files/ {
        proxy_pass http://dify_api/files/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

# HTTPS 配置 (可选 - 取消注释并配置证书路径)
# server {
#     listen 443 ssl;
#     server_name your-domain.com;
#
#     ssl_certificate /etc/ssl/certs/your-cert.pem;
#     ssl_certificate_key /etc/ssl/private/your-key.pem;
#
#     # ... 其余配置同上 ...
# }
NGINXEOF

# 启用站点配置
ln -sf /etc/nginx/sites-available/dify /etc/nginx/sites-enabled/dify
rm -f /etc/nginx/sites-enabled/default

# 测试配置
nginx -t

# 重启 Nginx
systemctl restart nginx 2>/dev/null || service nginx restart 2>/dev/null || nginx -s reload 2>/dev/null || true

echo ""
echo "=========================================="
echo "  Nginx 反向代理配置完成！"
echo "=========================================="
echo ""
echo "  现在可以通过以下地址访问:"
echo "    http://<服务器IP>          → Dify Web 界面"
echo "    http://<服务器IP>/api/     → Dify API"
echo ""
echo "  如需 HTTPS，请:"
echo "  1. 准备 SSL 证书"
echo "  2. 编辑 /etc/nginx/sites-available/dify"
echo "  3. 取消 HTTPS server 块的注释"
echo "  4. 运行: sudo nginx -s reload"
