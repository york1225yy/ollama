#!/bin/bash
# ============================================================
# 服务状态检查脚本
# ============================================================

echo "========================================="
echo "  服务状态检查"
echo "========================================="

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# ========== 1. 系统信息 ==========
echo -e "\n${YELLOW}[系统信息]${NC}"
echo "主机名: $(hostname)"
echo "IP 地址: $(hostname -I | awk '{print $1}')"

# ========== 2. GPU 状态 ==========
echo -e "\n${YELLOW}[GPU 状态]${NC}"
if nvidia-smi > /dev/null 2>&1; then
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader
    echo -e "${GREEN}✓ GPU 正常${NC}"
else
    echo -e "${RED}✗ GPU 不可用${NC}"
fi

# ========== 3. Ollama 状态 ==========
echo -e "\n${YELLOW}[Ollama 状态]${NC}"
if systemctl is-active --quiet ollama 2>/dev/null; then
    echo -e "${GREEN}✓ Ollama 服务运行中 (systemd)${NC}"
elif pgrep -x ollama > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama 进程运行中${NC}"
else
    echo -e "${RED}✗ Ollama 未运行${NC}"
fi

# API 检查
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Ollama API 可访问 (http://localhost:11434)${NC}"
    echo "已安装模型:"
    curl -s http://localhost:11434/api/tags | python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in data.get('models', []):
    print(f\"  - {m['name']} ({m.get('size', 'N/A')})\" if isinstance(m.get('size'), str) else f\"  - {m['name']} ({m.get('details', {}).get('parameter_size', 'N/A')})\")
" 2>/dev/null || ollama list 2>/dev/null
else
    echo -e "${RED}✗ Ollama API 不可访问${NC}"
fi

# ========== 4. Dify 状态 ==========
echo -e "\n${YELLOW}[Dify 状态]${NC}"
DIFY_DOCKER_DIR="$PROJECT_DIR/dify/docker"

if [ -d "$DIFY_DOCKER_DIR" ]; then
    cd "$DIFY_DOCKER_DIR"
    
    echo "Docker 容器状态:"
    docker compose ps 2>/dev/null || echo "无法获取容器状态"
    
    # Web 检查
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo -e "\n${GREEN}✓ Dify Web 可访问 (http://localhost)${NC}"
    else
        echo -e "\n${RED}✗ Dify Web 不可访问 (HTTP $HTTP_CODE)${NC}"
    fi
else
    echo -e "${RED}✗ Dify 未部署${NC}"
fi

# ========== 5. 网络端口 ==========
echo -e "\n${YELLOW}[端口监听]${NC}"
echo "关键端口:"
for port in 80 443 11434; do
    if ss -tlnp 2>/dev/null | grep -q ":$port " || netstat -tlnp 2>/dev/null | grep -q ":$port "; then
        echo -e "  端口 $port: ${GREEN}已监听${NC}"
    else
        echo -e "  端口 $port: ${RED}未监听${NC}"
    fi
done

# ========== 6. 防火墙提示 ==========
echo -e "\n${YELLOW}[网络访问]${NC}"
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo "如需从外部网络访问，确保以下端口已开放:"
echo "  - 80   (Dify Web):   http://${LOCAL_IP}"
echo "  - 443  (Dify HTTPS): https://${LOCAL_IP}"
echo "  - 11434 (Ollama API): http://${LOCAL_IP}:11434"

echo ""
echo -e "${GREEN}========================================="
echo "  状态检查完成"
echo "=========================================${NC}"
