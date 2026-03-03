#!/bin/bash
# ============================================================
# 停止所有服务
# ============================================================

set -e

echo "========================================="
echo "  停止所有服务"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ========== 1. 停止 Dify ==========
echo -e "\n${YELLOW}[1/2] 停止 Dify 服务...${NC}"
DIFY_DOCKER_DIR="$PROJECT_DIR/dify/docker"

if [ -d "$DIFY_DOCKER_DIR" ]; then
    cd "$DIFY_DOCKER_DIR"
    if docker compose version > /dev/null 2>&1; then
        docker compose down
    elif command -v docker-compose > /dev/null 2>&1; then
        docker-compose down
    else
        echo -e "${YELLOW}⚠ Docker Compose 不可用，跳过 Dify 停止${NC}"
    fi
    echo -e "${GREEN}✓ Dify 服务已停止${NC}"
else
    echo -e "${YELLOW}⚠ Dify 目录不存在，跳过${NC}"
fi

# ========== 2. 停止 Ollama ==========
echo -e "\n${YELLOW}[2/2] 停止 Ollama 服务...${NC}"
# 容器环境不使用 systemd，直接掉进程
if [ -f /tmp/ollama.pid ]; then
    PID=$(cat /tmp/ollama.pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        rm -f /tmp/ollama.pid
        echo -e "${GREEN}✓ Ollama 进程 (PID: $PID) 已终止${NC}"
    else
        rm -f /tmp/ollama.pid
        echo -e "${YELLOW}⚠ PID 文件存在但进程已结束${NC}"
    fi
elif pgrep -x ollama > /dev/null 2>&1; then
    pkill -x ollama
    echo -e "${GREEN}✓ Ollama 进程已终止${NC}"
else
    echo -e "${YELLOW}⚠ Ollama 未在运行${NC}"
fi

echo ""
echo -e "${GREEN}========================================="
echo "  所有服务已停止"
echo "=========================================${NC}"
