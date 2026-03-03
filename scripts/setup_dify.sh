#!/bin/bash
# ============================================================
# Dify 部署脚本 (Docker Compose 方式)
# ============================================================

set -e

echo "========================================="
echo "  Dify 平台部署"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIFY_DIR="$PROJECT_DIR/dify"

# ========== 1. 检查 Docker ==========
echo -e "\n${YELLOW}[1/4] 检查 Docker 环境...${NC}"
if ! command -v docker > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker 未安装，请先运行 install_nvidia.sh${NC}"
    exit 1
fi

if ! docker compose version > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker Compose 未安装${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker 和 Docker Compose 已就绪${NC}"

# ========== 2. 克隆 Dify 仓库 ==========
echo -e "\n${YELLOW}[2/4] 获取 Dify 源码...${NC}"
if [ -d "$DIFY_DIR" ]; then
    echo -e "${GREEN}✓ Dify 目录已存在${NC}"
    cd "$DIFY_DIR"
    # 尝试获取最新版本
    if [ -d ".git" ]; then
        echo "拉取最新代码..."
        git pull origin main 2>/dev/null || echo "跳过 git pull"
    fi
else
    echo "克隆 Dify 仓库..."
    git clone https://github.com/langgenius/dify.git "$DIFY_DIR"
    echo -e "${GREEN}✓ Dify 仓库克隆完成${NC}"
fi

cd "$DIFY_DIR/docker"

# ========== 3. 配置环境变量 ==========
echo -e "\n${YELLOW}[3/4] 配置 Dify 环境变量...${NC}"

# 复制默认环境变量文件
if [ ! -f ".env" ]; then
    cp .env.example .env 2>/dev/null || true
    echo -e "${GREEN}✓ 环境变量文件已创建${NC}"
else
    echo -e "${GREEN}✓ 环境变量文件已存在${NC}"
fi

# 获取本机局域网 IP
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo -e "检测到本机 IP: ${GREEN}${LOCAL_IP}${NC}"

# 修改关键配置
# 确保 Dify 可以通过网络访问
if grep -q "^EXPOSE_NGINX_PORT=" .env; then
    sed -i 's/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=80/' .env
fi

if grep -q "^EXPOSE_NGINX_SSL_PORT=" .env; then
    sed -i 's/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=443/' .env
fi

# 设置文件上传大小限制（支持图片上传）
if grep -q "^NGINX_CLIENT_MAX_BODY_SIZE=" .env; then
    sed -i 's/^NGINX_CLIENT_MAX_BODY_SIZE=.*/NGINX_CLIENT_MAX_BODY_SIZE=50m/' .env
fi

# 设置上传文件大小（支持较大图片）
if grep -q "^UPLOAD_FILE_SIZE_LIMIT=" .env; then
    sed -i 's/^UPLOAD_FILE_SIZE_LIMIT=.*/UPLOAD_FILE_SIZE_LIMIT=50/' .env
fi

echo -e "${GREEN}✓ 环境变量配置完成${NC}"

# ========== 4. 启动 Dify ==========
echo -e "\n${YELLOW}[4/4] 启动 Dify 服务...${NC}"
echo "首次启动需要拉取 Docker 镜像，可能需要几分钟..."

docker compose up -d

# 等待服务就绪
echo ""
echo "等待 Dify 服务启动..."
for i in $(seq 1 60); do
    if curl -s http://localhost/apps > /dev/null 2>&1 || curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null | grep -q "200\|301\|302"; then
        echo -e "${GREEN}✓ Dify 服务已就绪${NC}"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo -e "${YELLOW}⚠ Dify 启动中，请稍后手动检查${NC}"
    fi
    printf "."
    sleep 5
done

echo ""
echo -e "${GREEN}========================================="
echo "  Dify 部署完成！"
echo ""
echo "  访问地址:"
echo "    本地: http://localhost"
echo "    网络: http://${LOCAL_IP}"
echo ""
echo "  首次访问需要设置管理员账户"
echo "=========================================${NC}"
