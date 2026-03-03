#!/bin/bash
# ============================================================
# 一键启动所有服务
# ============================================================

set -e

echo "========================================="
echo "  启动所有服务"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ========== 1. 启动 Ollama ==========
echo -e "\n${YELLOW}[1/2] 启动 Ollama 服务...${NC}"
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama 已在运行${NC}"
else
    echo "以后台进程方式启动 Ollama..."
    export OLLAMA_HOST=0.0.0.0:11434
    export OLLAMA_ORIGINS='*'
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    OLLAMA_PID=$!
    echo "$OLLAMA_PID" > /tmp/ollama.pid
    echo "进程 PID: $OLLAMA_PID"
    sleep 3
fi

# 等待 Ollama 就绪
echo "等待 Ollama API 就绪..."
for i in $(seq 1 20); do
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Ollama API 已就绪${NC}"
        break
    fi
    if [ "$i" -eq 20 ]; then
        echo -e "${RED}✗ Ollama API 启动超时${NC}"
    fi
    sleep 2
done

# 确保模型已加载
echo "检查 Qwen2.5-VL 模型..."
if ollama list 2>/dev/null | grep -q "qwen2.5-vl"; then
    echo -e "${GREEN}✓ Qwen2.5-VL 模型已就绪${NC}"
else
    echo -e "${YELLOW}⚠ 模型未找到，正在拉取...${NC}"
    ollama pull qwen2.5-vl:7b
fi

# ========== 2. 启动 Dify ==========
echo -e "\n${YELLOW}[2/2] 启动 Dify 服务...${NC}"
DIFY_DOCKER_DIR="$PROJECT_DIR/dify/docker"

if [ -d "$DIFY_DOCKER_DIR" ]; then
    cd "$DIFY_DOCKER_DIR"
    # 自动选择 docker compose 命令
    if docker compose version > /dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    $COMPOSE_CMD up -d
    echo -e "${GREEN}✓ Dify 服务启动命令已执行${NC}"
    
    # 等待 Dify 就绪
    echo "等待 Dify 服务就绪..."
    for i in $(seq 1 60); do
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
            echo -e "${GREEN}✓ Dify 服务已就绪${NC}"
            break
        fi
        if [ "$i" -eq 60 ]; then
            echo -e "${YELLOW}⚠ Dify 仍在启动中，请稍后检查${NC}"
        fi
        printf "."
        sleep 5
    done
else
    echo -e "${RED}✗ Dify 目录不存在，请先运行 setup_dify.sh${NC}"
    exit 1
fi

# ========== 显示状态 ==========
LOCAL_IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}========================================="
echo "  所有服务已启动！"
echo ""
echo "  Ollama API: http://${LOCAL_IP}:11434"
echo "  Dify 平台:  http://${LOCAL_IP}"
echo ""
echo "  查看状态: bash scripts/check_status.sh"
echo "  停止服务: bash scripts/stop_all.sh"
echo "=========================================${NC}"
